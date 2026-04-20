const crypto = require('crypto');
const admin = require('firebase-admin');
const { onRequest, onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentCreated, onDocumentDeleted } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { defineSecret } = require('firebase-functions/params');
const Anthropic = require('@anthropic-ai/sdk');

admin.initializeApp();

const db = admin.firestore();

const REGION = 'us-central1';
const PROJECT_ID =
  process.env.GCLOUD_PROJECT ||
  JSON.parse(process.env.FIREBASE_CONFIG || '{}').projectId ||
  'moriknit-ceea9';

const RAVELRY_CLIENT_ID = 'e87a14a430bd98b1d5dcb3e851ce8a3d';
const anthropicApiKey = defineSecret('ANTHROPIC_API_KEY');
const ravelryClientSecret = defineSecret('RAVELRY_CLIENT_SECRET');
const RAVELRY_AUTH_ENDPOINT = 'https://www.ravelry.com/oauth2/auth';
const RAVELRY_TOKEN_ENDPOINT = 'https://www.ravelry.com/oauth2/token';
const RAVELRY_API_BASE = 'https://api.ravelry.com';
const APP_CALLBACK_URI = 'com.moriknit.app://oauth-callback/ravelry';
const CALLBACK_URL = `https://${REGION}-${PROJECT_ID}.cloudfunctions.net/ravelryAuthCallback`;

function setCors(res) {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Headers', 'Authorization, Content-Type');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
}

function handleOptions(req, res) {
  if (req.method === 'OPTIONS') {
    setCors(res);
    res.status(204).send('');
    return true;
  }
  return false;
}

async function verifyFirebaseUser(req) {
  const header = req.get('Authorization') || '';
  const match = header.match(/^Bearer (.+)$/);
  if (!match) {
    throw new Error('Missing Firebase ID token.');
  }
  return admin.auth().verifyIdToken(match[1]);
}

function connectionDoc(uid) {
  return db.collection('_ravelryConnections').doc(uid);
}

function stateDoc(state) {
  return db.collection('_ravelryOAuthStates').doc(state);
}

async function tokenRequest(params) {
  const clientSecret = ravelryClientSecret.value();
  if (!clientSecret) {
    throw new Error('RAVELRY_CLIENT_SECRET is not configured on the server.');
  }

  const body = new URLSearchParams(params);
  const basicAuth = Buffer.from(
    `${RAVELRY_CLIENT_ID}:${clientSecret}`,
    'utf8',
  ).toString('base64');

  const response = await fetch(RAVELRY_TOKEN_ENDPOINT, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      Accept: 'application/json',
      Authorization: `Basic ${basicAuth}`,
    },
    body,
  });

  const text = await response.text();
  if (!response.ok) {
    throw new Error(`Ravelry token request failed (${response.status}): ${text}`);
  }

  try {
    return JSON.parse(text);
  } catch (_) {
    throw new Error(`Ravelry token response was not JSON: ${text.slice(0, 200)}`);
  }
}

async function fetchRavelryJson(path, accessToken, query) {
  // URLSearchParams encodes commas as %2C which Ravelry API rejects.
  // Build query string manually to preserve commas in values like include=a,b,c.
  let urlStr = `${RAVELRY_API_BASE}${path}`;
  if (query) {
    const qs = Object.entries(query)
      .filter(([, v]) => v != null)
      .map(([k, v]) => `${encodeURIComponent(k)}=${String(v)}`)
      .join('&');
    if (qs) urlStr += '?' + qs;
  }

  const response = await fetch(urlStr, {
    headers: {
      Authorization: `Bearer ${accessToken}`,
      Accept: 'application/json',
    },
  });

  const text = await response.text();
  if (!response.ok) {
    const urlObj = new URL(urlStr);
    throw new Error(
      `Ravelry API failed (${response.status}) for ${urlObj.pathname}${urlObj.search}: ${text}`,
    );
  }

  return JSON.parse(text);
}

async function fetchRavelryJsonWithFallback(
  candidates,
  accessToken,
  contextLabel,
) {
  const failures = [];

  for (const candidate of candidates) {
    try {
      return await fetchRavelryJson(candidate.path, accessToken, candidate.query);
    } catch (error) {
      const message =
        error instanceof Error ? error.message : 'Unknown Ravelry API error.';
      failures.push(message);
      console.error(`Ravelry ${contextLabel} candidate failed:`, {
        path: candidate.path,
        query: candidate.query || null,
        error: message,
      });
    }
  }

  throw new Error(
    `All Ravelry ${contextLabel} candidates failed: ${failures.join(' | ')}`,
  );
}

async function getValidConnection(uid) {
  const snap = await connectionDoc(uid).get();
  if (!snap.exists) {
    throw new Error('Ravelry is not connected.');
  }

  const data = snap.data();
  if (!data) {
    throw new Error('Ravelry connection is empty.');
  }

  const expiresAt = typeof data.expiresAt === 'number' ? data.expiresAt : 0;
  const now = Date.now();
  if (data.accessToken && expiresAt > now + 60 * 1000) {
    return data;
  }

  if (!data.refreshToken) {
    throw new Error('Ravelry refresh token is missing.');
  }

  const refreshed = await tokenRequest({
    grant_type: 'refresh_token',
    refresh_token: data.refreshToken,
    redirect_uri: APP_CALLBACK_URI,
  });

  const next = {
    ...data,
    accessToken: refreshed.access_token,
    refreshToken: refreshed.refresh_token || data.refreshToken,
    expiresAt:
      Date.now() + ((Number(refreshed.expires_in) || 3600) * 1000),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  await connectionDoc(uid).set(next, { merge: true });
  return next;
}

async function withUser(req, res, fn) {
  try {
    setCors(res);
    if (handleOptions(req, res)) return;
    const decoded = await verifyFirebaseUser(req);
    await fn(decoded);
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown server error.';
    // 연결 끊김·토큰 만료 관련 오류는 401 반환 → 클라이언트가 재연결 유도 가능
    const isAuthError =
      message.includes('Missing Firebase ID token') ||
      message.includes('not connected') ||
      message.includes('refresh token') ||
      message.includes('Ravelry refresh token') ||
      message.includes('refresh_failed');
    const status = isAuthError ? 401 : 400;
    res.status(status).json({ error: message });
  }
}

// admins/{uid} 문서 생성 시 Custom Claims admin:true 설정
// Firestore DB가 asia-northeast3(서울)이므로 트리거 리전도 동일하게 설정
exports.onAdminCreated = onDocumentCreated(
  { document: 'admins/{uid}', region: 'asia-northeast3' },
  async (event) => {
    const uid = event.params.uid;
    await admin.auth().setCustomUserClaims(uid, { admin: true });
    console.log(`Admin claim set for uid: ${uid}`);
  },
);

// admins/{uid} 문서 삭제 시 Custom Claims 제거
exports.onAdminDeleted = onDocumentDeleted(
  { document: 'admins/{uid}', region: 'asia-northeast3' },
  async (event) => {
    const uid = event.params.uid;
    await admin.auth().setCustomUserClaims(uid, { admin: false });
    console.log(`Admin claim removed for uid: ${uid}`);
  },
);

exports.ravelryAuthStart = onRequest(
  { region: REGION, secrets: [ravelryClientSecret] },
  async (req, res) => {
    await withUser(req, res, async (decoded) => {
      if (req.method !== 'POST') {
        res.status(405).json({ error: 'Method not allowed.' });
        return;
      }

      const state = crypto.randomUUID();
      await stateDoc(state).set({
        uid: decoded.uid,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const authUrl = new URL(RAVELRY_AUTH_ENDPOINT);
      authUrl.searchParams.set('response_type', 'code');
      authUrl.searchParams.set('client_id', RAVELRY_CLIENT_ID);
      authUrl.searchParams.set('redirect_uri', CALLBACK_URL);
      authUrl.searchParams.set('state', state);
      authUrl.searchParams.set('scope', 'offline');

      res.json({ authUrl: authUrl.toString() });
    });
  },
);

exports.ravelryAuthCallback = onRequest(
  { region: REGION, secrets: [ravelryClientSecret] },
  async (req, res) => {
    const state = req.query.state;
    const code = req.query.code;
    const error = req.query.error;

    const fail = (message) => {
      console.log('Ravelry callback failed:', {
        state,
        error,
        message,
        query: req.query,
      });
      const redirect = new URL(APP_CALLBACK_URI);
      redirect.searchParams.set('status', 'error');
      redirect.searchParams.set('message', message);
      res.redirect(302, redirect.toString());
    };

    try {
      if (typeof state !== 'string' || !state) {
        fail('Missing OAuth state.');
        return;
      }

      const stateSnap = await stateDoc(state).get();
      if (!stateSnap.exists) {
        fail('OAuth state expired.');
        return;
      }

      const { uid } = stateSnap.data() || {};
      await stateDoc(state).delete().catch(() => {});

      if (!uid) {
        fail('Missing user for OAuth state.');
        return;
      }

      if (typeof error === 'string' && error.length > 0) {
        fail(error);
        return;
      }

      if (typeof code !== 'string' || !code) {
        fail('Missing authorization code.');
        return;
      }

      const token = await tokenRequest({
        grant_type: 'authorization_code',
        code,
        redirect_uri: CALLBACK_URL,
      });

      const currentUser = await fetchRavelryJson(
        '/current_user.json',
        token.access_token,
      );
      const username = currentUser.user?.username || currentUser.user?.name || null;

      await connectionDoc(uid).set({
        username,
        accessToken: token.access_token,
        refreshToken: token.refresh_token || null,
        expiresAt: Date.now() + ((Number(token.expires_in) || 3600) * 1000),
        connectedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log('Ravelry callback success:', {
        uid,
        username,
        hasRefreshToken: Boolean(token.refresh_token),
      });

      const redirect = new URL(APP_CALLBACK_URI);
      redirect.searchParams.set('status', 'success');
      if (username) redirect.searchParams.set('username', username);
      res.redirect(302, redirect.toString());
    } catch (err) {
      fail(err instanceof Error ? err.message : 'OAuth callback failed.');
    }
  },
);

exports.ravelrySession = onRequest(
  { region: REGION, secrets: [ravelryClientSecret] },
  async (req, res) => {
    await withUser(req, res, async (decoded) => {
      const snap = await connectionDoc(decoded.uid).get();
      if (!snap.exists) {
        res.json({ isLoggedIn: false });
        return;
      }
      const data = snap.data() || {};

      // 토큰 만료 여부 확인 (5분 여유)
      const expiresAt = typeof data.expiresAt === 'number' ? data.expiresAt : 0;
      const isTokenExpired = !data.accessToken || expiresAt <= Date.now() + 5 * 60 * 1000;

      // refresh_token이 없고 토큰이 만료된 경우 → 재연결 필요
      if (isTokenExpired && !data.refreshToken) {
        res.json({ isLoggedIn: false, reason: 'token_expired_no_refresh' });
        return;
      }

      // refresh_token이 있으면 미리 갱신 시도
      if (isTokenExpired && data.refreshToken) {
        try {
          await getValidConnection(decoded.uid);
        } catch (refreshError) {
          console.error('Ravelry session pre-refresh failed:', refreshError);
          res.json({ isLoggedIn: false, reason: 'refresh_failed' });
          return;
        }
      }

      res.json({
        isLoggedIn: true,
        username: data.username || null,
      });
    });
  },
);

exports.ravelryDisconnect = onRequest(
  { region: REGION, secrets: [ravelryClientSecret] },
  async (req, res) => {
    await withUser(req, res, async (decoded) => {
      if (req.method !== 'POST') {
        res.status(405).json({ error: 'Method not allowed.' });
        return;
      }
      await connectionDoc(decoded.uid).delete().catch(() => {});
      res.json({ ok: true });
    });
  },
);

async function proxyRavelry(req, res, candidatesBuilder, contextLabel) {
  await withUser(req, res, async (decoded) => {
    const connection = await getValidConnection(decoded.uid);
    const username = connection.username;
    if (!username) {
      res.status(400).json({ error: 'Ravelry username is missing on the server.' });
      return;
    }
    const candidates = candidatesBuilder(username, req);
    const data = await fetchRavelryJsonWithFallback(
      candidates,
      connection.accessToken,
      contextLabel,
    );
    console.log('Ravelry proxy response keys:', Object.keys(data), 'context:', contextLabel);
    res.json(data);
  });
}

exports.ravelryStash = onRequest(
  { region: REGION, secrets: [ravelryClientSecret] },
  async (req, res) => {
    await proxyRavelry(
      req,
      res,
      (username) => [
        { path: `/people/${username}/stash.json` },
        { path: `/people/${username}/stash/list.json` },
        { path: `/people/${username}/stash/search.json`, query: { page_size: 50 } },
      ],
      'stash',
    );
  },
);

exports.ravelryLibrary = onRequest(
  { region: REGION, secrets: [ravelryClientSecret] },
  async (req, res) => {
    await proxyRavelry(
      req,
      res,
      (username) => [
        { path: `/people/${username}/library.json`, query: { page_size: 50, include: 'pattern' } },
        { path: `/people/${username}/library/search.json`, query: { page_size: 50, include: 'pattern' } },
        { path: `/people/${username}/library/volumes.json`, query: { page_size: 50, include: 'pattern' } },
      ],
      'library',
    );
  },
);

exports.ravelryProjects = onRequest(
  { region: REGION, secrets: [ravelryClientSecret] },
  async (req, res) => {
    await proxyRavelry(
      req,
      res,
      (username) => [
        { path: `/people/${username}/projects.json` },
        { path: `/people/${username}/projects/list.json` },
        { path: `/people/${username}/projects/search.json`, query: { page_size: 50 } },
      ],
      'projects',
    );
  },
);

// ── Ravelry 상세 & CRUD ───────────────────────────────────────────────────────

exports.ravelryPatternDetail = onRequest(
  { region: REGION, secrets: [ravelryClientSecret] },
  async (req, res) => {
    await withUser(req, res, async (decoded) => {
      const connection = await getValidConnection(decoded.uid);
      const patternId = req.query.id;
      if (!patternId) { res.status(400).json({ error: 'Pattern ID is required.' }); return; }
      const data = await fetchRavelryJson(
        `/patterns/${patternId}.json`,
        connection.accessToken,
        { include: 'pattern_author,craft,pattern_categories,photos,printing' },
      );
      res.json(data);
    });
  },
);

exports.ravelryProjectDetail = onRequest(
  { region: REGION, secrets: [ravelryClientSecret] },
  async (req, res) => {
    await withUser(req, res, async (decoded) => {
      const connection = await getValidConnection(decoded.uid);
      const username = connection.username;
      const projectId = req.query.id;
      if (!projectId) { res.status(400).json({ error: 'Project ID is required.' }); return; }
      const data = await fetchRavelryJson(
        `/projects/${username}/${projectId}.json`,
        connection.accessToken,
      );
      res.json(data);
    });
  },
);

exports.ravelryPatternFiles = onRequest(
  { region: REGION, secrets: [ravelryClientSecret] },
  async (req, res) => {
    await withUser(req, res, async (decoded) => {
      const connection = await getValidConnection(decoded.uid);
      const patternId = req.query.id;
      if (!patternId) { res.status(400).json({ error: 'Pattern ID is required.' }); return; }
      const data = await fetchRavelryJson(
        `/patterns/${patternId}/files.json`,
        connection.accessToken,
      );
      res.json(data);
    });
  },
);

exports.ravelryPatternDownload = onRequest(
  { region: REGION, secrets: [ravelryClientSecret], timeoutSeconds: 120, memory: '512MiB' },
  async (req, res) => {
    await withUser(req, res, async (decoded) => {
      const connection = await getValidConnection(decoded.uid);
      const encodedUrl = req.query.url;
      if (!encodedUrl) { res.status(400).json({ error: 'File URL is required.' }); return; }
      const fileUrl = decodeURIComponent(encodedUrl);
      const response = await fetch(fileUrl, {
        headers: { Authorization: `Bearer ${connection.accessToken}` },
      });
      if (!response.ok) {
        res.status(response.status).json({ error: `Download failed: ${response.status}` });
        return;
      }
      const contentType = response.headers.get('content-type') || 'application/octet-stream';
      const buffer = await response.arrayBuffer();
      res.set('Content-Type', contentType);
      res.send(Buffer.from(buffer));
    });
  },
);

exports.ravelryCreateProject = onRequest(
  { region: REGION, secrets: [ravelryClientSecret] },
  async (req, res) => {
    await withUser(req, res, async (decoded) => {
      if (req.method !== 'POST') { res.status(405).json({ error: 'Method Not Allowed' }); return; }
      const connection = await getValidConnection(decoded.uid);
      const username = connection.username;
      const response = await fetch(`${RAVELRY_API_BASE}/projects/${username}/create.json`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${connection.accessToken}`,
          'Content-Type': 'application/json',
          Accept: 'application/json',
        },
        body: JSON.stringify(req.body),
      });
      const text = await response.text();
      if (!response.ok) { res.status(response.status).json({ error: `Ravelry API error: ${text.slice(0, 200)}` }); return; }
      res.json(JSON.parse(text));
    });
  },
);

exports.ravelryUpdateProject = onRequest(
  { region: REGION, secrets: [ravelryClientSecret] },
  async (req, res) => {
    await withUser(req, res, async (decoded) => {
      if (req.method !== 'POST') { res.status(405).json({ error: 'Method Not Allowed' }); return; }
      const connection = await getValidConnection(decoded.uid);
      const username = connection.username;
      const projectId = req.query.id;
      if (!projectId) { res.status(400).json({ error: 'Project ID is required.' }); return; }
      const response = await fetch(`${RAVELRY_API_BASE}/projects/${username}/${projectId}.json`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${connection.accessToken}`,
          'Content-Type': 'application/json',
          Accept: 'application/json',
        },
        body: JSON.stringify(req.body),
      });
      const text = await response.text();
      if (!response.ok) { res.status(response.status).json({ error: `Ravelry API error: ${text.slice(0, 200)}` }); return; }
      res.json(JSON.parse(text));
    });
  },
);

// ── 카카오 커스텀 토큰 발급 ─────────────────────────────────
exports.kakaoCustomToken = onRequest(
  { region: REGION, serviceAccount: 'firebase-adminsdk-fbsvc@moriknit-ceea9.iam.gserviceaccount.com' },
  async (req, res) => {
    setCors(res);
    if (req.method === 'OPTIONS') { res.status(204).send(''); return; }
    if (req.method !== 'POST') { res.status(405).json({ error: 'Method Not Allowed' }); return; }

    const { accessToken } = req.body;
    if (!accessToken) { res.status(400).json({ error: 'accessToken is required' }); return; }

    try {
      // 카카오 사용자 정보 조회
      const kakaoRes = await fetch('https://kapi.kakao.com/v2/user/me', {
        headers: { Authorization: `Bearer ${accessToken}` },
      });
      if (!kakaoRes.ok) {
        res.status(401).json({ error: 'Invalid Kakao access token' });
        return;
      }
      const kakaoUser = await kakaoRes.json();
      const kakaoId = String(kakaoUser.id);

      const profile = kakaoUser.kakao_account?.profile ?? {};
      const email = kakaoUser.kakao_account?.email ?? '';
      const displayName = profile.nickname ?? '';
      const photoURL = profile.profile_image_url ?? '';

      // Firebase 커스텀 토큰 생성
      const uid = `kakao_${kakaoId}`;
      const customToken = await admin.auth().createCustomToken(uid, {
        provider: 'kakao',
        displayName,
        email,
        photoURL,
      });

      // Firestore 사용자 문서 upsert (신규 가입 처리)
      const userRef = db.collection('users').doc(uid);
      const userDoc = await userRef.get();
      if (!userDoc.exists) {
        await userRef.set({
          uid,
          email,
          displayName,
          photoURL,
          provider: 'kakao',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          lastActiveAt: admin.firestore.FieldValue.serverTimestamp(),
          moriBalance: 10000,
          subscription: { planId: 'pro', status: 'active' },
          usage: { swatchCount: 0, projectCount: 0, counterCount: 0, editorSaveCount: 0, postsThisMonth: 0 },
        });
      } else {
        await userRef.set(
          { displayName, photoURL, email, lastActiveAt: admin.firestore.FieldValue.serverTimestamp() },
          { merge: true },
        );
      }

      res.status(200).json({ customToken });
    } catch (err) {
      console.error('kakaoCustomToken error:', err);
      res.status(500).json({ error: 'Internal server error' });
    }
  },
);

// ──────────────────────────────────────────────────────────────────────────────
// parseKnittingPattern — PDF/이미지 도안을 Claude AI로 파싱하여 단계로그 구조로 반환
// ──────────────────────────────────────────────────────────────────────────────
exports.parseKnittingPattern = onCall(
  {
    region: REGION,
    secrets: [anthropicApiKey],
    timeoutSeconds: 120,
    memory: '512MiB',
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError('unauthenticated', '로그인이 필요합니다.');

    const { storagePath, mimeType, fileName, translateLanguage } = request.data;
    if (!storagePath || !mimeType || !fileName) {
      throw new HttpsError('invalid-argument', '필수 항목이 누락됐습니다.');
    }
    const needsKorean = translateLanguage === 'ko';

    // 파일 크기 제한 (10MB)
    const bucket = admin.storage().bucket();
    const fileRef = bucket.file(storagePath);
    const [metadata] = await fileRef.getMetadata();
    const fileSize = parseInt(metadata.size, 10);
    if (fileSize > 10 * 1024 * 1024) {
      throw new HttpsError('invalid-argument', '파일 크기가 너무 큽니다. 10MB 이하의 파일을 사용해 주세요.');
    }

    // Firebase Storage에서 파일 다운로드
    let fileBuffer;
    try {
      [fileBuffer] = await fileRef.download();
    } catch (err) {
      throw new HttpsError('not-found', '파일을 불러올 수 없습니다. 다시 시도해 주세요.');
    }
    const base64Data = fileBuffer.toString('base64');

    const client = new Anthropic({ apiKey: anthropicApiKey.value().trim() });

    const systemPromptBase = `You are a knitting pattern parser.
Parse the provided knitting pattern (PDF or image) and extract structured step-by-step instructions.
Output ONLY valid JSON, no markdown, no extra text.`;

    const systemPromptKo = `${systemPromptBase}

JSON structure (with Korean translation):
{
  "title": "pattern title",
  "materials": "yarn, needle size, other materials as a single string",
  "gauge": "gauge information as a string",
  "sizes": "available sizes as a string",
  "sections": [
    {
      "id": "section_1",
      "title": "Section name in English (e.g., Cast On, Body, Sleeve, etc.)",
      "titleKo": "섹션 이름 한국어 번역 (예: 코 잡기, 몸통, 소매 등)",
      "steps": [
        {"id": "step_1_1", "instruction": "Step instruction text in original language", "instructionKo": "단계 지시 한국어 번역"},
        {"id": "step_1_2", "instruction": "Next step", "instructionKo": "다음 단계 한국어 번역"}
      ]
    }
  ]
}

Important rules:
- Keep each step as ONE actionable instruction (not too long, not too short)
- instruction: use the original language of the pattern
- titleKo and instructionKo: must be natural Korean translation
- Translate all knitting terms accurately (e.g., "cast on" → "코 잡기", "knit" → "겉뜨기", "purl" → "안뜨기", "bind off" → "코 막음")
- section IDs: section_1, section_2, ...
- step IDs: step_{sectionIndex}_{stepIndex} (1-based)`;

    const systemPromptDefault = `${systemPromptBase}

JSON structure:
{
  "title": "pattern title",
  "materials": "yarn, needle size, other materials as a single string",
  "gauge": "gauge information as a string",
  "sizes": "available sizes as a string",
  "sections": [
    {
      "id": "section_1",
      "title": "Section name (e.g., Cast On, Body, Sleeve, etc.)",
      "steps": [
        {"id": "step_1_1", "instruction": "Step instruction text"},
        {"id": "step_1_2", "instruction": "Next step"}
      ]
    }
  ]
}

Important rules:
- Keep each step as ONE actionable instruction (not too long, not too short)
- Use the original language of the pattern for instructions
- If Korean, keep Korean. If English, keep English.
- section IDs: section_1, section_2, ...
- step IDs: step_{sectionIndex}_{stepIndex} (1-based)`;

    const systemPrompt = needsKorean ? systemPromptKo : systemPromptDefault;

    const contentBlock =
      mimeType === 'application/pdf'
        ? {
            type: 'document',
            source: {
              type: 'base64',
              media_type: 'application/pdf',
              data: base64Data,
            },
          }
        : {
            type: 'image',
            source: {
              type: 'base64',
              media_type: mimeType,
              data: base64Data,
            },
          };

    let message;
    try {
      message = await client.messages.create({
        model: 'claude-sonnet-4-6',
        max_tokens: 8192,
        system: systemPrompt,
        messages: [
          {
            role: 'user',
            content: [
              contentBlock,
              {
                type: 'text',
                text: 'Parse this knitting pattern into the JSON structure described.',
              },
            ],
          },
        ],
      });
    } catch (err) {
      throw new HttpsError('internal', 'AI 분석 중 오류가 발생했습니다. 다시 시도해 주세요.');
    }

    const rawText = message.content[0]?.text ?? '';
    let parsed;
    try {
      parsed = JSON.parse(rawText);
    } catch {
      // JSON 코드블록 감지 후 재시도
      const jsonMatch = rawText.match(/```(?:json)?\s*([\s\S]*?)```/);
      if (jsonMatch) {
        try {
          parsed = JSON.parse(jsonMatch[1]);
        } catch {
          throw new HttpsError('internal', '도안 파싱에 실패했습니다. 다른 파일로 시도해 주세요.');
        }
      } else {
        const { HttpsError } = require('firebase-functions/v2/https');
        throw new HttpsError('internal', '도안 파싱에 실패했습니다. 다른 파일로 시도해 주세요.');
      }
    }

    return { result: parsed };
  },
);


// ──────────────────────────────────────────────────────────────────────────────
// updateLandingStats — 랜딩 통계 자동 집계 (매일 자정 KST)
// users / public_projects / market_items 컬렉션 카운트 → app_config/landing_stats
// ──────────────────────────────────────────────────────────────────────────────
exports.updateLandingStats = onSchedule(
  {
    schedule: '0 15 * * *', // UTC 15:00 = KST 자정
    region: REGION,
    timeZone: 'Asia/Seoul',
  },
  async () => {
    const [usersSnap, projectsSnap, marketSnap] = await Promise.all([
      db.collection('users').count().get(),
      db.collection('public_projects').count().get(),
      db.collection('market_items').count().get(),
    ]);
    await db.collection('app_config').doc('landing_stats').set({
      statsUsers: usersSnap.data().count,
      statsProjects: projectsSnap.data().count,
      statsMarket: marketSnap.data().count,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(`Landing stats updated: users=${usersSnap.data().count}, projects=${projectsSnap.data().count}, market=${marketSnap.data().count}`);
  },
);
