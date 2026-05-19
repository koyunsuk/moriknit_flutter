const crypto = require('crypto');
const admin = require('firebase-admin');
const { onRequest, onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentCreated, onDocumentDeleted, onDocumentUpdated } = require('firebase-functions/v2/firestore');
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

exports.ravelryCreateStash = onRequest(
  { region: REGION, secrets: [ravelryClientSecret] },
  async (req, res) => {
    await withUser(req, res, async (decoded) => {
      if (req.method !== 'POST') { res.status(405).json({ error: 'Method Not Allowed' }); return; }
      const connection = await getValidConnection(decoded.uid);
      const username = connection.username;
      const stashData = req.body.stash ?? req.body;
      const response = await fetch(`${RAVELRY_API_BASE}/people/${username}/stash/create.json`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${connection.accessToken}`,
          'Content-Type': 'application/json',
          Accept: 'application/json',
        },
        body: JSON.stringify(stashData),
      });
      const text = await response.text();
      if (!response.ok) { res.status(response.status).json({ error: `Ravelry API error: ${text.slice(0, 200)}` }); return; }
      res.json(JSON.parse(text));
    });
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
      const projectBody = req.body.project ?? req.body;
      // 이슈 #662 — silent failure 추적용 진단 로그
      console.log('[ravelryCreateProject] uid=%s username=%s body=%j', decoded.uid, username, projectBody);
      const response = await fetch(`${RAVELRY_API_BASE}/projects/${username}/create.json`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${connection.accessToken}`,
          'Content-Type': 'application/json',
          Accept: 'application/json',
        },
        body: JSON.stringify(projectBody),
      });
      const text = await response.text();
      console.log('[ravelryCreateProject] status=%s body=%s', response.status, text.slice(0, 500));
      if (!response.ok) { res.status(response.status).json({ error: `Ravelry API error: ${text.slice(0, 200)}` }); return; }
      // 이슈 #662 — 200 OK + 빈/비정상 응답 검증 (project.id 없으면 422)
      let parsed;
      try { parsed = JSON.parse(text); } catch (e) {
        console.error('[ravelryCreateProject] JSON parse failed:', e.message);
        res.status(502).json({ error: 'Ravelry returned invalid JSON' });
        return;
      }
      const projectIdValue = parsed?.project?.id ?? parsed?.id;
      if (!projectIdValue || Number(projectIdValue) <= 0) {
        console.error('[ravelryCreateProject] project.id missing in response:', JSON.stringify(parsed).slice(0, 300));
        res.status(422).json({ error: 'Ravelry response missing project.id', body: text.slice(0, 200) });
        return;
      }
      res.json(parsed);
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

// ── 이슈 #644 Phase 7 — Ravelry yarn DB 검색/상세 ─────────────────────────────
// Ravelry 글로벌 yarn DB(10만+ 항목) 검색 → YarnModel.ravelryYarnId 매핑
// /yarns/search.json + /yarns/{id}.json 프록시
exports.ravelryYarnsSearch = onRequest(
  { region: REGION, secrets: [ravelryClientSecret] },
  async (req, res) => {
    await withUser(req, res, async (decoded) => {
      const connection = await getValidConnection(decoded.uid);
      const query = req.query.query;
      if (!query || (typeof query === 'string' && !query.trim())) {
        res.status(400).json({ error: 'query parameter is required.' });
        return;
      }
      const page = req.query.page || '1';
      const pageSize = req.query.page_size || '25';
      const data = await fetchRavelryJson(
        '/yarns/search.json',
        connection.accessToken,
        {
          query: encodeURIComponent(String(query).trim()),
          page,
          page_size: pageSize,
        },
      );
      res.json(data);
    });
  },
);

exports.ravelryYarnDetail = onRequest(
  { region: REGION, secrets: [ravelryClientSecret] },
  async (req, res) => {
    await withUser(req, res, async (decoded) => {
      const connection = await getValidConnection(decoded.uid);
      const yarnId = req.query.id;
      if (!yarnId) {
        res.status(400).json({ error: 'Yarn ID is required.' });
        return;
      }
      const data = await fetchRavelryJson(
        `/yarns/${yarnId}.json`,
        connection.accessToken,
      );
      res.json(data);
    });
  },
);

// ── 카카오 커스텀 토큰 발급 ─────────────────────────────────
// #728/#729 — 카카오 로그인 + 익명 → 카카오 업그레이드 흐름 지원.
//   요청 body:
//     { accessToken: string, anonymousIdToken?: string }
//   anonymousIdToken 전달 시:
//     - 익명 uid를 검증하고 그 uid를 그대로 사용해 카카오 프로필을 merge.
//     - 익명 사용자의 데이터를 유지하면서 카카오 계정 정보만 연결.
//   미전달 시:
//     - 기존 흐름대로 `kakao_{kakaoId}` uid로 신규/기존 처리.
exports.kakaoCustomToken = onRequest(
  { region: REGION, serviceAccount: 'firebase-adminsdk-fbsvc@moriknit-ceea9.iam.gserviceaccount.com' },
  async (req, res) => {
    setCors(res);
    if (req.method === 'OPTIONS') { res.status(204).send(''); return; }
    if (req.method !== 'POST') { res.status(405).json({ error: 'Method Not Allowed' }); return; }

    const { accessToken, anonymousIdToken } = req.body || {};
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

      // 1) 익명 사용자 업그레이드 분기 — 익명 uid 보존
      let uid;
      let isUpgrade = false;
      if (anonymousIdToken) {
        try {
          const decoded = await admin.auth().verifyIdToken(anonymousIdToken);
          if (decoded.firebase?.sign_in_provider === 'anonymous') {
            uid = decoded.uid;
            isUpgrade = true;
          }
        } catch (verifyErr) {
          console.warn('kakaoCustomToken: anonymousIdToken verify failed', verifyErr);
        }
      }

      // 2) 일반 흐름 — kakao_{id} uid
      if (!uid) {
        uid = `kakao_${kakaoId}`;
      }

      // Firebase 커스텀 토큰 생성
      const customToken = await admin.auth().createCustomToken(uid, {
        provider: 'kakao',
        kakaoId,
        displayName,
        email,
        photoURL,
      });

      // Firestore 사용자 문서 upsert
      const userRef = db.collection('users').doc(uid);
      const userDoc = await userRef.get();
      if (!userDoc.exists) {
        await userRef.set({
          uid,
          email,
          displayName,
          photoURL,
          provider: 'kakao',
          kakaoId,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          lastActiveAt: admin.firestore.FieldValue.serverTimestamp(),
          moriBalance: 10000,
          subscription: { planId: 'pro', status: 'active' },
          usage: { swatchCount: 0, projectCount: 0, counterCount: 0, editorSaveCount: 0, postsThisMonth: 0 },
        });
      } else {
        // 업그레이드: 기존 익명 문서를 카카오 정보로 보강 (기존 데이터 보존)
        const updates = {
          provider: 'kakao',
          kakaoId,
          lastActiveAt: admin.firestore.FieldValue.serverTimestamp(),
          isAnonymous: false,
        };
        if (email) updates.email = email;
        if (displayName) updates.displayName = displayName;
        if (photoURL) updates.photoURL = photoURL;
        await userRef.set(updates, { merge: true });
      }

      res.status(200).json({ customToken, uid, isUpgrade });
    } catch (err) {
      console.error('kakaoCustomToken error:', err);
      res.status(500).json({ error: 'Internal server error' });
    }
  },
);

// ──────────────────────────────────────────────────────────────────────────────
// parseKnittingPattern — PDF/이미지 도안을 Claude AI로 파싱하여 단계로그 구조로 반환
// ──────────────────────────────────────────────────────────────────────────────

// 이슈 #873 — 인입 메일 자동 AI 분석 트리거(onAiJobCreated)와 공유하는 내부 헬퍼.
//   parseKnittingPattern 내부 분석 로직을 함수로 분리해
//   onAiJobCreated 에서도 재사용한다. 동작/응답 schema 변경 없음.
//   입력: { fileBuffer, mimeType, needsKorean, model? }
//   출력: parsed JSON ({ title, materials, gauge, sizes, sections: [...] })
//   throws: { type: 'too_large'|'api_error'|'parse_failed', message }
async function runAiPatternAnalysis({ fileBuffer, mimeType, needsKorean, model }) {
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
          source: { type: 'base64', media_type: 'application/pdf', data: base64Data },
        }
      : {
          type: 'image',
          source: { type: 'base64', media_type: mimeType, data: base64Data },
        };

  const usedModel = model || 'claude-sonnet-4-6';
  const maxTokens = model && /haiku/i.test(model) ? 2000 : 16000;

  let message;
  try {
    message = await client.messages.create({
      model: usedModel,
      max_tokens: maxTokens,
      system: systemPrompt,
      messages: [
        {
          role: 'user',
          content: [
            contentBlock,
            { type: 'text', text: 'Parse this knitting pattern into the JSON structure described.' },
          ],
        },
      ],
    });
  } catch (err) {
    console.error('[runAiPatternAnalysis] Claude API error:', err?.status, err?.message, err?.error);
    const detail = err?.message ?? String(err);
    const e = new Error(`AI 분석 중 오류가 발생했습니다: ${detail}`);
    e.kind = 'api_error';
    throw e;
  }

  if (message && message.usage) {
    console.log('[runAiPatternAnalysis] usage', {
      model: usedModel,
      input_tokens: message.usage.input_tokens,
      output_tokens: message.usage.output_tokens,
    });
  }

  const rawText = message.content[0]?.text ?? '';
  let parsed;
  // Strategy 1: Direct JSON parse
  try { parsed = JSON.parse(rawText); } catch (_) {}
  // Strategy 2: Extract from markdown code block
  if (!parsed) {
    const jsonMatch = rawText.match(/```(?:json)?\s*([\s\S]*?)```/);
    if (jsonMatch) {
      try { parsed = JSON.parse(jsonMatch[1].trim()); } catch (_) {}
    }
  }
  // Strategy 3: Extract first { ... } block
  if (!parsed) {
    const start = rawText.indexOf('{');
    const end = rawText.lastIndexOf('}');
    if (start !== -1 && end > start) {
      try { parsed = JSON.parse(rawText.substring(start, end + 1)); } catch (_) {}
    }
  }
  if (!parsed) {
    console.error('[runAiPatternAnalysis] JSON 추출 실패. rawText 앞 200자:', rawText.slice(0, 200));
    const e = new Error('도안 파싱에 실패했습니다.');
    e.kind = 'parse_failed';
    throw e;
  }
  return parsed;
}

exports.parseKnittingPattern = onCall(
  {
    region: REGION,
    secrets: [anthropicApiKey],
    timeoutSeconds: 240,
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

    let parsed;
    try {
      parsed = await runAiPatternAnalysis({ fileBuffer, mimeType, needsKorean });
    } catch (e) {
      if (e.kind === 'parse_failed') {
        throw new HttpsError('internal', '도안 파싱에 실패했습니다. 다른 파일로 시도해 주세요.');
      }
      throw new HttpsError('internal', e.message || 'AI 분석 중 오류가 발생했습니다.');
    }
    return { result: parsed };
  },
);

/* 이슈 #873 — 아래 원본 inline 분석 블록은 runAiPatternAnalysis 로 이전.
   호환을 위해 주석으로 감싸 dead-code 보존. 향후 안정화 확인 후 완전 제거 예정.
exports.__legacyParseKnittingPatternBody = (async () => {
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
        max_tokens: 16000,
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
      console.error('parseKnittingPattern: Claude API error:', err?.status, err?.message, err?.error);
      const detail = err?.message ?? String(err);
      throw new HttpsError('internal', `AI 분석 중 오류가 발생했습니다: ${detail}`);
    }

    const rawText = message.content[0]?.text ?? '';
    let parsed;

    // Strategy 1: Direct JSON parse
    try { parsed = JSON.parse(rawText); } catch (_) {}

    // Strategy 2: Extract from markdown code block
    if (!parsed) {
      const jsonMatch = rawText.match(/```(?:json)?\s*([\s\S]*?)```/);
      if (jsonMatch) {
        try { parsed = JSON.parse(jsonMatch[1].trim()); } catch (_) {}
      }
    }

    // Strategy 3: Extract first { ... } block
    if (!parsed) {
      const start = rawText.indexOf('{');
      const end = rawText.lastIndexOf('}');
      if (start !== -1 && end > start) {
        try { parsed = JSON.parse(rawText.substring(start, end + 1)); } catch (_) {}
      }
    }

    if (!parsed) {
      console.error('parseKnittingPattern: JSON 추출 실패. rawText 앞 200자:', rawText.slice(0, 200));
      throw new Error('도안 파싱에 실패했습니다. 다른 파일로 시도해 주세요.');
    }

    return { result: parsed };
  });
*/
// 이슈 #873 — legacy 인라인 블록 끝.


// ──────────────────────────────────────────────────────────────────────────────
// sendBroadcastPush — 어드민 발송 (이슈 #817 Phase 1 + 이슈 #834 Phase 2)
//   인자: { title, body, deepLink?, audience? }  // audience: 'all' | 'free' | 'pro' | 'business'
//   인증: admins/{uid} 문서 존재 여부 + Custom Claims admin:true 둘 다 허용
//   흐름:
//     1) collectionGroup('fcm_tokens') 으로 전체 토큰 수집
//     2) audience 필터링 (users/{uid}.subscription.planId)
//     3) admin.messaging().sendEachForMulticast (500개씩 청크)
//     4) 무효 토큰(registration-token-not-registered / invalid-argument) 자동 삭제
//     5) notifications/{auto} 에 발송 이력 기록
//     6) #834 — 대상 사용자별 @moriknit DM 룸에 메시지 append (읽음 추적용)
//     7) #834 — notifications.{readCount, recipientUids} 업데이트
//     8) { totalTokens, successCount, failureCount, prunedCount, recipientCount } 반환
// ──────────────────────────────────────────────────────────────────────────────

// 이슈 #834 — @moriknit 시스템 봇 UID/메타 (lib/core/constants/system_users.dart 와 동일)
const MORIKNIT_SYSTEM_UID = 'moriknit_system';
const MORIKNIT_SYSTEM_HANDLE = 'moriknit';
const MORIKNIT_SYSTEM_NAME = '모리니트';

/// DM 룸 deterministic ID — 두 uid 알파벳 정렬 후 `__` 조인.
/// dm_rooms/{deterministicId} 형태로 사용 → 동일 두 사용자 간 룸 중복 방지.
function dmRoomIdFor(uid1, uid2) {
  const [a, b] = [uid1, uid2].sort();
  return `${a}__${b}`;
}

/// @moriknit 시스템 봇 사용자 도큐먼트 lazy create.
/// users/{moriknit_system} 가 없으면 생성, 있으면 no-op.
async function ensureMoriknitSystemUser() {
  const ref = db.collection('users').doc(MORIKNIT_SYSTEM_UID);
  const snap = await ref.get();
  if (snap.exists) return;
  await ref.set({
    uid: MORIKNIT_SYSTEM_UID,
    handle: MORIKNIT_SYSTEM_HANDLE,
    displayName: MORIKNIT_SYSTEM_NAME,
    photoURL: '',
    bio: '모리니트 공식 채널입니다.',
    isSystem: true,
    provider: 'system',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    lastActiveAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
  console.log('[ensureMoriknitSystemUser] created system bot user');
}

/// 어드민 푸시 → 각 대상 사용자에게 @moriknit DM 발송 (개별 룸).
///   - dm_rooms/{deterministicId} : 없으면 batch.set, 있으면 metadata update
///   - dm_rooms/{id}/messages/{auto} : 새 메시지 append
///   - readBy: {} (수신자 진입 시 클라이언트가 채움)
///   - meta: { broadcastId, deepLink, source: 'broadcast', isRichBroadcast }
///   - lastMessage, lastMessageAt, unreadCount.{recipientUid} increment
///
/// 이슈 #848 — 풍부한 카드 메시지:
///   imageUrl / bodyDelta(Quill JSON) / linkUrl 중 하나라도 비어있지 않으면
///   메시지에 함께 저장 + meta.isRichBroadcast=true 표시. 클라이언트는 이 플래그로
///   리치 카드 위젯과 일반 텍스트 버블을 분기 렌더링.
/// 결과: { dmCount }
async function fanoutBroadcastDms({
  recipientUids,
  title,
  body,
  deepLink,
  broadcastId,
  imageUrl,
  bodyDelta,
  linkUrl,
}) {
  if (recipientUids.length === 0) return { dmCount: 0 };
  await ensureMoriknitSystemUser();

  // 본문 텍스트 — 푸시 title + body 합치기 (DM 메시지 본문)
  const dmText = [title, body].filter((s) => s && s.trim()).join('\n').trim();
  if (!dmText) return { dmCount: 0 };

  // 이슈 #848 — 리치 필드 정규화
  const imageUrlStr = (imageUrl || '').toString().trim();
  const bodyDeltaStr = (bodyDelta || '').toString().trim();
  const linkUrlStr = (linkUrl || '').toString().trim();
  const isRichBroadcast =
    imageUrlStr.length > 0 || bodyDeltaStr.length > 0 || linkUrlStr.length > 0;

  let dmCount = 0;
  // Firestore batch 한도 500 → 한 사용자당 최대 2 write(룸 + 메시지) → 안전하게 200명씩 청크
  const chunkSize = 200;
  for (let i = 0; i < recipientUids.length; i += chunkSize) {
    const chunk = recipientUids.slice(i, i + chunkSize);
    // 기존 룸 존재 여부 미리 조회 (룸 신규 생성 시 participantNames 등 채우기 위함)
    const roomIds = chunk.map((uid) => dmRoomIdFor(MORIKNIT_SYSTEM_UID, uid));
    const roomSnaps = await Promise.all(
      roomIds.map((id) => db.collection('dm_rooms').doc(id).get())
    );
    // 사용자 displayName/handle 스냅샷 한 번에 조회 (UI 표시용)
    const userSnaps = await Promise.all(
      chunk.map((uid) => db.collection('users').doc(uid).get())
    );

    const batch = db.batch();
    chunk.forEach((uid, idx) => {
      const roomId = roomIds[idx];
      const roomRef = db.collection('dm_rooms').doc(roomId);
      const msgRef = roomRef.collection('messages').doc();
      const userData = userSnaps[idx].exists ? (userSnaps[idx].data() || {}) : {};
      const recipientName = userData.displayName || '';
      const recipientHandle = userData.handle || '';
      const recipientPhoto = userData.photoURL || '';

      if (!roomSnaps[idx].exists) {
        // 신규 룸 — participantNames 등 풀세팅
        batch.set(roomRef, {
          participants: [MORIKNIT_SYSTEM_UID, uid],
          participantNames: {
            [MORIKNIT_SYSTEM_UID]: MORIKNIT_SYSTEM_NAME,
            [uid]: recipientName,
          },
          participantHandles: {
            [MORIKNIT_SYSTEM_UID]: MORIKNIT_SYSTEM_HANDLE,
            [uid]: recipientHandle,
          },
          participantPhotos: {
            [MORIKNIT_SYSTEM_UID]: '',
            [uid]: recipientPhoto,
          },
          lastMessage: dmText,
          lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
          unreadCount: {
            [MORIKNIT_SYSTEM_UID]: 0,
            [uid]: 1,
          },
          isSystemChannel: true,
        });
      } else {
        // 기존 룸 — metadata 만 update + unreadCount 증가
        batch.update(roomRef, {
          lastMessage: dmText,
          lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
          [`unreadCount.${uid}`]: admin.firestore.FieldValue.increment(1),
          isSystemChannel: true,
        });
      }

      // 메시지 도큐먼트
      batch.set(msgRef, {
        senderId: MORIKNIT_SYSTEM_UID,
        senderName: MORIKNIT_SYSTEM_NAME,
        text: dmText,
        // 이슈 #848 — 풍부한 카드 메시지 필드 (없으면 빈 문자열)
        imageUrl: imageUrlStr,
        bodyDelta: bodyDeltaStr,
        linkUrl: linkUrlStr,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        // 이슈 #834 — 읽음 추적 (DM 진입 시 클라이언트가 본인 uid 추가).
        readBy: {},
        // 발송 메타 (어드민 통계 + 딥링크 이동에 사용)
        meta: {
          source: 'broadcast',
          broadcastId: broadcastId || null,
          deepLink: deepLink || null,
          // 이슈 #848 — 클라이언트가 리치 카드 분기 렌더링에 사용
          isRichBroadcast,
        },
      });
      dmCount += 1;
    });

    try {
      await batch.commit();
    } catch (e) {
      console.warn('[fanoutBroadcastDms] batch failed:', e.message);
    }
  }

  return { dmCount };
}

async function assertIsAdmin(uid) {
  if (!uid) throw new HttpsError('unauthenticated', '로그인이 필요합니다.');
  // 1) Custom Claims 우선 (Custom Claims 마이그레이션 진행 중)
  try {
    const user = await admin.auth().getUser(uid);
    if (user.customClaims && user.customClaims.admin === true) return;
  } catch (_) { /* fallthrough */ }
  // 2) admins/{uid} 컬렉션 폴백 — isAdminProvider와 동일 정책
  const doc = await db.collection('admins').doc(uid).get();
  if (!doc.exists) {
    throw new HttpsError('permission-denied', '관리자 권한이 필요합니다.');
  }
}

exports.sendBroadcastPush = onCall(
  {
    region: REGION,
    timeoutSeconds: 540,
    memory: '512MiB',
  },
  async (request) => {
    const uid = request.auth?.uid;
    await assertIsAdmin(uid);

    const data = request.data || {};
    const title = (data.title || '').toString().trim();
    const body = (data.body || '').toString().trim();
    const deepLink = (data.deepLink || '').toString().trim();
    const audience = (data.audience || 'all').toString().trim().toLowerCase();
    // 이슈 #848 — 풍부한 카드 메시지 입력 (어드민 폼 backgroundImageUrl / popupBodyDelta / popupLinkUrl)
    const imageUrl = (data.imageUrl || '').toString().trim();
    const bodyDelta = (data.bodyDelta || '').toString();
    const linkUrl = (data.linkUrl || '').toString().trim();

    if (!title && !body) {
      throw new HttpsError('invalid-argument', '제목 또는 본문을 입력해 주세요.');
    }
    const allowedAudiences = ['all', 'free', 'pro', 'business', 'starter'];
    if (!allowedAudiences.includes(audience)) {
      throw new HttpsError('invalid-argument', `audience 값이 올바르지 않습니다: ${audience}`);
    }

    // 1) 토큰 수집 — collectionGroup
    const tokenSnap = await db.collectionGroup('fcm_tokens').get();
    // userUid 별로 토큰 모음 + audience 필터링 준비
    const byUser = new Map(); // uid -> [{ token, ref }]
    tokenSnap.forEach((doc) => {
      // 경로: users/{uid}/fcm_tokens/{token}
      const segments = doc.ref.path.split('/');
      const usersIdx = segments.indexOf('users');
      if (usersIdx === -1 || !segments[usersIdx + 1]) return;
      const ownerUid = segments[usersIdx + 1];
      const tokenStr = doc.id;
      if (!tokenStr) return;
      const arr = byUser.get(ownerUid) || [];
      arr.push({ token: tokenStr, ref: doc.ref });
      byUser.set(ownerUid, arr);
    });

    // 2) audience 필터 — recipientUids 도 함께 수집 (#834 DM fanout 용)
    let candidateRefs = []; // { token, ref }
    const recipientUidSet = new Set();
    if (audience === 'all') {
      for (const [ownerUid, list] of byUser.entries()) {
        candidateRefs.push(...list);
        recipientUidSet.add(ownerUid);
      }
    } else {
      // users/{uid} 문서 chunk get → planId 검사
      const uids = [...byUser.keys()];
      const chunkSize = 30; // Firestore 'in' 한도 회피
      for (let i = 0; i < uids.length; i += chunkSize) {
        const chunk = uids.slice(i, i + chunkSize);
        const docs = await Promise.all(chunk.map((u) => db.collection('users').doc(u).get()));
        docs.forEach((userDoc) => {
          if (!userDoc.exists) return;
          const planId = userDoc.data()?.subscription?.planId || 'free';
          if (planId === audience) {
            const arr = byUser.get(userDoc.id) || [];
            candidateRefs.push(...arr);
            recipientUidSet.add(userDoc.id);
          }
        });
      }
    }
    // 시스템 봇 자체는 발송 대상에서 제외
    recipientUidSet.delete(MORIKNIT_SYSTEM_UID);
    const recipientUids = [...recipientUidSet];

    if (candidateRefs.length === 0 && recipientUids.length === 0) {
      return {
        totalTokens: 0,
        successCount: 0,
        failureCount: 0,
        prunedCount: 0,
        recipientCount: 0,
        dmCount: 0,
        notificationId: null,
      };
    }

    // 3) 발송 — 500개씩 청크
    const messaging = admin.messaging();
    const notification = { title: title || undefined, body: body || undefined };
    const dataPayload = {};
    if (deepLink) dataPayload.deepLink = deepLink;

    let successCount = 0;
    let failureCount = 0;
    const invalidRefs = [];

    const chunkSize = 500;
    for (let i = 0; i < candidateRefs.length; i += chunkSize) {
      const slice = candidateRefs.slice(i, i + chunkSize);
      const tokens = slice.map((s) => s.token);
      let resp;
      try {
        resp = await messaging.sendEachForMulticast({
          tokens,
          notification,
          data: dataPayload,
          android: {
            priority: 'high',
            notification: { channelId: 'default' },
          },
          apns: {
            payload: {
              aps: { sound: 'default' },
            },
          },
        });
      } catch (err) {
        console.error('[sendBroadcastPush] chunk failed:', err);
        failureCount += tokens.length;
        continue;
      }
      successCount += resp.successCount;
      failureCount += resp.failureCount;
      resp.responses.forEach((r, idx) => {
        if (!r.success) {
          const code = r.error && r.error.code;
          if (
            code === 'messaging/registration-token-not-registered' ||
            code === 'messaging/invalid-argument' ||
            code === 'messaging/invalid-registration-token'
          ) {
            invalidRefs.push(slice[idx].ref);
          }
        }
      });
    }

    // 4) 무효 토큰 삭제 (450개씩 batch)
    let prunedCount = 0;
    const batchSize = 450;
    for (let i = 0; i < invalidRefs.length; i += batchSize) {
      const batch = db.batch();
      const sub = invalidRefs.slice(i, i + batchSize);
      sub.forEach((ref) => batch.delete(ref));
      try {
        await batch.commit();
        prunedCount += sub.length;
      } catch (e) {
        console.warn('[sendBroadcastPush] prune batch failed:', e.message);
      }
    }

    // 5) 발송 이력 기록 (#834 — recipientUids/readCount 포함)
    const historyRef = await db.collection('notifications').add({
      title,
      body,
      deepLink: deepLink || null,
      audience,
      totalTokens: candidateRefs.length,
      successCount,
      failureCount,
      prunedCount,
      // 이슈 #834 — 읽음 추적 통계
      recipientCount: recipientUids.length,
      recipientUids,          // 어드민에서 미읽음 목록 조회 시 사용
      readUids: [],           // DM 읽음 시 클라이언트가 arrayUnion 추가
      readCount: 0,
      sentBy: uid,
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 6) 이슈 #834 — 대상 사용자별 @moriknit DM fanout (읽음 추적용)
    //    이슈 #848 — 풍부한 카드 (imageUrl/bodyDelta/linkUrl) 함께 전달
    let dmCount = 0;
    try {
      const fanoutResult = await fanoutBroadcastDms({
        recipientUids,
        title,
        body,
        deepLink,
        broadcastId: historyRef.id,
        imageUrl,
        bodyDelta,
        linkUrl,
      });
      dmCount = fanoutResult.dmCount;
    } catch (e) {
      console.error('[sendBroadcastPush] DM fanout failed:', e);
    }

    return {
      totalTokens: candidateRefs.length,
      successCount,
      failureCount,
      prunedCount,
      recipientCount: recipientUids.length,
      dmCount,
      notificationId: historyRef.id,
    };
  },
);

// ──────────────────────────────────────────────────────────────────────────────
// markBroadcastRead — 사용자가 @moriknit DM 메시지를 읽었을 때 호출 (#834)
//   인자: { broadcastId, messageId, roomId }
//   인증: 본인 (request.auth.uid)
//   흐름:
//     1) dm_rooms/{roomId}/messages/{messageId}.readBy[uid] = serverTimestamp
//     2) notifications/{broadcastId}.readUids arrayUnion uid + readCount = readUids.length
//        (트랜잭션 — race condition 방지)
//
// 클라이언트는 dm_chat_screen 에서 메시지 stream 받을 때 broadcastId 가 있는
// 미읽음 메시지를 본 함수로 한 번에 표시.
// ──────────────────────────────────────────────────────────────────────────────
exports.markBroadcastRead = onCall(
  { region: REGION },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError('unauthenticated', '로그인이 필요합니다.');

    const data = request.data || {};
    const broadcastId = (data.broadcastId || '').toString().trim();
    const messageId = (data.messageId || '').toString().trim();
    const roomId = (data.roomId || '').toString().trim();
    if (!broadcastId || !messageId || !roomId) {
      throw new HttpsError('invalid-argument', 'broadcastId / messageId / roomId 가 필요합니다.');
    }

    // 1) DM 메시지 readBy 업데이트
    const msgRef = db.collection('dm_rooms').doc(roomId).collection('messages').doc(messageId);
    try {
      await msgRef.set({
        readBy: { [uid]: admin.firestore.FieldValue.serverTimestamp() },
      }, { merge: true });
    } catch (e) {
      console.warn('[markBroadcastRead] message readBy update failed:', e.message);
    }

    // 2) notifications.readUids arrayUnion + readCount 갱신
    const broadcastRef = db.collection('notifications').doc(broadcastId);
    try {
      await db.runTransaction(async (tx) => {
        const snap = await tx.get(broadcastRef);
        if (!snap.exists) return;
        const cur = snap.data() || {};
        const readUids = Array.isArray(cur.readUids) ? cur.readUids : [];
        if (readUids.includes(uid)) return;
        const next = [...readUids, uid];
        tx.update(broadcastRef, {
          readUids: next,
          readCount: next.length,
        });
      });
    } catch (e) {
      console.warn('[markBroadcastRead] notifications update failed:', e.message);
    }

    return { ok: true };
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


// ──────────────────────────────────────────────────────────────────────────────
// 이슈 #831 — 킨들 패턴 이메일 인입 (Phase 2)
//
// 사용자별 고유 이메일 (`{handle}_{key}@pattern.moriknit.com`) → SendGrid
// Inbound Parse webhook → 본 함수 → Firebase Storage + Firestore 자동 등록.
//
//   inboundEmailHandler:      SendGrid Inbound Parse webhook (HTTP POST)
//   regenerateInboundEmailKey: 사용자 인입 키 재발급 (호출형, 본인만)
//
// 사용자 작업 (다음 단계 — Phase 1):
//   1) SendGrid 계정 생성 + 도메인 인증 (`pattern.moriknit.com`)
//   2) Inbound Parse 설정: Host=`pattern.moriknit.com`,
//      Webhook URL=`https://us-central1-moriknit-ceea9.cloudfunctions.net/inboundEmailHandler`
//   3) DNS MX 레코드 추가: `pattern.moriknit.com  10  mx.sendgrid.net`
// ──────────────────────────────────────────────────────────────────────────────

const Busboy = require('busboy');

// 인입 키 영숫자 4자 (소문자) — 충돌 가능성 매우 낮음(~1.7M), 짧고 외우기 쉬움.
function generateInboundEmailKey() {
  const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
  let out = '';
  for (let i = 0; i < 4; i += 1) {
    out += alphabet[crypto.randomInt(0, alphabet.length)];
  }
  return out;
}

// `Display Name <handle_key@pattern.moriknit.com>` 또는 `handle_key@...` 모두 처리.
function extractEmailAddress(rawTo) {
  if (!rawTo) return null;
  const angleMatch = String(rawTo).match(/<([^>]+)>/);
  const candidate = (angleMatch ? angleMatch[1] : String(rawTo)).trim().toLowerCase();
  return candidate.includes('@') ? candidate : null;
}

// `{handle}_{key}@pattern.moriknit.com` 형식에서 handle/key 분리.
//   - handle: ^[a-z0-9_]{3,20}$ (UserModel 정책과 동일)
//   - key: ^[a-z0-9]{4,8}$
// 도메인은 환경변수 INBOUND_EMAIL_DOMAIN > 기본 'pattern.moriknit.com'.
function parseInboundEmailAddress(addr) {
  if (!addr) return null;
  const lower = addr.toLowerCase();
  const expectedDomain = (process.env.INBOUND_EMAIL_DOMAIN || 'pattern.moriknit.com').toLowerCase();
  const atIdx = lower.indexOf('@');
  if (atIdx <= 0) return null;
  const local = lower.slice(0, atIdx);
  const domain = lower.slice(atIdx + 1);
  if (domain !== expectedDomain) return null;
  const underscoreIdx = local.lastIndexOf('_');
  if (underscoreIdx <= 0 || underscoreIdx >= local.length - 1) return null;
  const handle = local.slice(0, underscoreIdx);
  const key = local.slice(underscoreIdx + 1);
  if (!/^[a-z0-9_]{3,20}$/.test(handle)) return null;
  if (!/^[a-z0-9]{4,8}$/.test(key)) return null;
  return { handle, key };
}

// busboy 로 multipart/form-data 파싱 → { fields, files }
function parseMultipartRequest(req) {
  return new Promise((resolve, reject) => {
    const headers = req.headers || {};
    const contentType = headers['content-type'] || '';
    if (!contentType.toLowerCase().startsWith('multipart/')) {
      resolve({ fields: {}, files: [] });
      return;
    }

    let busboy;
    try {
      busboy = Busboy({ headers, limits: { fileSize: 25 * 1024 * 1024 } });
    } catch (err) {
      reject(err);
      return;
    }

    const fields = {};
    const files = [];

    busboy.on('field', (name, value) => {
      fields[name] = value;
    });

    busboy.on('file', (name, stream, info) => {
      const { filename, mimeType } = info || {};
      const chunks = [];
      let truncated = false;
      stream.on('data', (chunk) => chunks.push(chunk));
      stream.on('limit', () => { truncated = true; });
      stream.on('end', () => {
        if (truncated) {
          console.warn(`[inboundEmail] file truncated (>25MB): ${filename}`);
          return;
        }
        files.push({
          fieldName: name,
          filename: filename || `${name}.bin`,
          mimeType: mimeType || 'application/octet-stream',
          buffer: Buffer.concat(chunks),
        });
      });
    });

    busboy.on('error', reject);
    busboy.on('finish', () => resolve({ fields, files }));

    // Firebase Functions 는 req.rawBody (Buffer) 제공.
    if (req.rawBody) {
      busboy.end(req.rawBody);
    } else {
      req.pipe(busboy);
    }
  });
}

// 파일 확장자에서 PDF/이미지만 통과시킴 (스팸/악성 첨부 1차 차단).
const ALLOWED_INBOUND_EXTENSIONS = new Set([
  'pdf', 'png', 'jpg', 'jpeg', 'gif', 'webp', 'heic',
]);
function isAllowedAttachment(filename, mimeType) {
  const ext = (filename || '').split('.').pop().toLowerCase();
  if (ALLOWED_INBOUND_EXTENSIONS.has(ext)) return true;
  if (mimeType === 'application/pdf') return true;
  if (mimeType && mimeType.startsWith('image/')) return true;
  return false;
}

function sanitizeFilename(name) {
  if (!name) return 'attachment.bin';
  // 경로 구분자/제어문자 제거. ASCII 영역 보존, 한글은 underscore로.
  return name
    .replace(/[\\/]/g, '_')
    .replace(/[ -<>:"|?*]/g, '_')
    .replace(/[^\x20-\x7e]/g, '_')
    .slice(-120);
}

// ─── 이슈 #870 — Dropbox 추가 백업 helpers ─────────────────────────────────
// 모바일 OAuth 와 동일한 Public App (PKCE) client_id 사용 — secret 불필요.
const DROPBOX_CLIENT_ID = '807t0lx4fvthfep';

// Dropbox refresh_token 으로 새 access_token 교환.
//   응답 { access_token, expires_in, token_type } — refresh_token 은 그대로 재사용.
async function refreshDropboxToken(refreshToken) {
  const body = new URLSearchParams({
    grant_type: 'refresh_token',
    refresh_token: refreshToken,
    client_id: DROPBOX_CLIENT_ID,
  });
  const resp = await fetch('https://api.dropboxapi.com/oauth2/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: body.toString(),
  });
  if (!resp.ok) {
    const text = await resp.text();
    throw new Error(`refresh failed: ${resp.status} ${text}`);
  }
  const json = await resp.json();
  const accessToken = json.access_token;
  if (!accessToken) throw new Error('refresh response missing access_token');
  const expiresInSec = Number(json.expires_in || 0);
  const expiresAt = expiresInSec > 0
    ? new Date(Date.now() + expiresInSec * 1000)
    : null;
  return { accessToken, expiresAt };
}

// 사용자 본인 Dropbox 의 지정 폴더로 첨부 백업.
//   - private/dropbox 도큐먼트 없으면 건너뜀 (Dropbox 미연결)
//   - uploadFolder 빈값이면 건너뜀
//   - access_token 만료 + refresh_token 있으면 자동 갱신 후 Firestore 동기화
async function uploadAttachmentsToUserDropbox({ uid, attachments }) {
  const ref = db.collection('users').doc(uid)
    .collection('private').doc('dropbox');
  const snap = await ref.get();
  if (!snap.exists) return; // 미연결 → 건너뜀
  const data = snap.data() || {};
  const folderRaw = (data.uploadFolder || '').toString();
  if (!folderRaw.trim()) return; // 폴더 미지정 → 건너뜀

  let accessToken = data.accessToken;
  const refreshToken = data.refreshToken;
  const expiresAt = data.expiresAt;
  const expiresMs = expiresAt && typeof expiresAt.toMillis === 'function'
    ? expiresAt.toMillis()
    : (typeof expiresAt === 'number' ? expiresAt : null);

  if (expiresMs && expiresMs < Date.now() + 60 * 1000 && refreshToken) {
    try {
      const refreshed = await refreshDropboxToken(refreshToken);
      accessToken = refreshed.accessToken;
      await ref.update({
        accessToken,
        expiresAt: refreshed.expiresAt
          ? admin.firestore.Timestamp.fromDate(refreshed.expiresAt)
          : admin.firestore.FieldValue.delete(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (err) {
      console.warn('[inboundEmail] Dropbox token refresh failed:', err.message);
      return;
    }
  }

  if (!accessToken) return;

  // 폴더 끝 슬래시 보정.
  const folder = folderRaw.endsWith('/') ? folderRaw : `${folderRaw}/`;

  // Dropbox SDK 가 fetch 를 필요로 함 (Node 20 글로벌 fetch 사용).
  const { Dropbox } = require('dropbox');
  const dbx = new Dropbox({ accessToken, fetch });

  const now = Date.now();
  // 확장성 위한 source 별 서브폴더 분리.
  //   - inbound/      ← SendGrid 자동 (이메일 수신)
  //   - ai-generated/ ← 향후 변환기 결과
  //   - shared/       ← 향후 공유 수신
  //   - (root)        ← 사용자가 직접 업로드한 파일 (#871 폴링 대상)
  // 모리니트 자동 저장은 inbound/ 안. 사용자 root 직접 추가만 모리니트가 새 도안으로 인지.
  const inboundFolder = `${folder}inbound/`;
  for (let i = 0; i < attachments.length; i += 1) {
    const att = attachments[i];
    const safeName = sanitizeFilename(att.filename);
    const path = `${inboundFolder}${now}_${i}_${safeName}`;
    try {
      await dbx.filesUpload({
        path,
        contents: att.buffer,
        mode: { '.tag': 'add' },
        autorename: true,
      });
    } catch (err) {
      // 개별 파일 실패는 다음 파일로 진행 (Firebase Storage 는 이미 저장됨).
      console.warn('[inboundEmail] Dropbox upload skipped:', path, err.message);
    }
  }
}

// SendGrid Inbound Parse webhook 수신.
//   - method: POST multipart/form-data
//   - 필드: to, from, subject, text, html, attachments(개수), attachment1, attachment2, ...
//
// 응답:
//   - 항상 200 OK (SendGrid 재시도 폭주 방지).
//     매칭 실패/거절은 로그로만 남기고 본문에 reason 포함.
exports.inboundEmailHandler = onRequest(
  {
    region: REGION,
    timeoutSeconds: 240,
    memory: '512MiB',
  },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Method Not Allowed' });
      return;
    }

    let parsed;
    try {
      parsed = await parseMultipartRequest(req);
    } catch (err) {
      console.error('[inboundEmail] multipart parse failed:', err);
      res.status(200).json({ ok: false, reason: 'parse_failed' });
      return;
    }

    const { fields, files } = parsed;
    const rawTo = fields.to || fields.envelope_to || '';
    const rawFrom = fields.from || '';
    const subject = (fields.subject || '').toString().slice(0, 200);

    // 다중 수신자 시 첫 번째 주소만 처리.
    const firstTo = String(rawTo).split(/[,;]/)[0];
    const toAddr = extractEmailAddress(firstTo);
    const parsedAddr = parseInboundEmailAddress(toAddr);

    if (!parsedAddr) {
      console.log('[inboundEmail] reject: invalid recipient', {
        to: rawTo, from: rawFrom, subject,
      });
      res.status(200).json({ ok: false, reason: 'invalid_recipient' });
      return;
    }

    // handle + key 로 users 조회.
    const userSnap = await db
      .collection('users')
      .where('handle', '==', parsedAddr.handle)
      .where('inboundEmailKey', '==', parsedAddr.key)
      .limit(1)
      .get();

    if (userSnap.empty) {
      console.log('[inboundEmail] reject: no matching user', {
        handle: parsedAddr.handle, key: parsedAddr.key, from: rawFrom,
      });
      res.status(200).json({ ok: false, reason: 'no_user' });
      return;
    }

    const userDoc = userSnap.docs[0];
    const uid = userDoc.id;

    // 첨부 필터링 (SendGrid는 attachment1, attachment2, ... 로 보냄).
    const attachments = files.filter((f) =>
      f.fieldName.startsWith('attachment')
      && isAllowedAttachment(f.filename, f.mimeType),
    );

    if (attachments.length === 0) {
      console.log('[inboundEmail] reject: no allowed attachments', {
        uid, fromCount: files.length, from: rawFrom,
      });
      res.status(200).json({ ok: false, reason: 'no_attachment' });
      return;
    }

    const bucket = admin.storage().bucket();
    const now = Date.now();
    const uploaded = [];

    for (let i = 0; i < attachments.length; i += 1) {
      const att = attachments[i];
      const safeName = sanitizeFilename(att.filename);
      const storagePath = `users/${uid}/inbound_patterns/${now}_${i}_${safeName}`;
      const fileRef = bucket.file(storagePath);
      try {
        await fileRef.save(att.buffer, {
          metadata: {
            contentType: att.mimeType,
            metadata: {
              source: 'emailInbound',
              originalFilename: att.filename,
              fromEmail: extractEmailAddress(rawFrom) || '',
              subject,
            },
          },
        });
        // 도큐먼트에 storagePath 만 기록 (signed URL 은 클라이언트가 직접 요청).
        uploaded.push({
          storagePath,
          filename: att.filename,
          mimeType: att.mimeType,
          sizeBytes: att.buffer.length,
        });
      } catch (err) {
        console.error('[inboundEmail] upload failed:', storagePath, err);
      }
    }

    if (uploaded.length === 0) {
      res.status(200).json({ ok: false, reason: 'upload_failed' });
      return;
    }

    // 이슈 #870 — Dropbox 추가 백업 (사용자 폴더 + 토큰 둘 다 있을 때만).
    //   안전 4중 장치:
    //     1) Firebase Storage 저장은 이미 위에서 완료 (변경 없음)
    //     2) users/{uid}/private/dropbox 도큐먼트 없으면 건너뜀
    //     3) uploadFolder 빈 값이면 건너뜀
    //     4) try-catch 외부 감싸기 — Dropbox 실패해도 본 흐름 정상 종료
    try {
      await uploadAttachmentsToUserDropbox({
        uid,
        attachments,
      });
    } catch (err) {
      console.warn('[inboundEmail] Dropbox backup skipped:', err.message);
    }

    // Firestore 도큐먼트 생성: users/{uid}/pattern_files/{auto}
    //   - 기존 'Dropbox 임포트' 경로(`pattern_files`)와 동일한 큐를 공유.
    //   - sourceType: 'emailInbound' — 라이브러리·뷰어에서 출처 표시.
    //   - status: 'pending_review' — 자동 등록 직후 사용자 1회 확인 (Phase 4 게이트).
    const patternFilesRef = db.collection('users').doc(uid).collection('pattern_files');
    const batch = db.batch();
    const createdIds = [];
    for (const file of uploaded) {
      const docRef = patternFilesRef.doc();
      createdIds.push(docRef.id);
      batch.set(docRef, {
        ownerUid: uid,
        sourceType: 'emailInbound',
        status: 'pending_review',
        storagePath: file.storagePath,
        filename: file.filename,
        mimeType: file.mimeType,
        sizeBytes: file.sizeBytes,
        subject,
        fromEmail: extractEmailAddress(rawFrom) || '',
        receivedAt: admin.firestore.FieldValue.serverTimestamp(),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();

    // 사용자 FCM 푸시 알림 (best-effort, 실패해도 200 응답).
    try {
      const tokensSnap = await db
        .collection('users').doc(uid)
        .collection('fcm_tokens')
        .get();
      const tokens = tokensSnap.docs.map((d) => d.id).filter(Boolean);
      if (tokens.length > 0) {
        const title = '새 도안이 도착했어요';
        const body = `${attachments.length}개 첨부 파일이 라이브러리에 추가됐어요. 확인해 보세요.`;
        await admin.messaging().sendEachForMulticast({
          tokens,
          notification: { title, body },
          data: {
            deepLink: '/pattern-files',
            source: 'emailInbound',
          },
          android: {
            priority: 'high',
            notification: { channelId: 'default' },
          },
          apns: { payload: { aps: { sound: 'default' } } },
        });
      }
    } catch (err) {
      console.warn('[inboundEmail] push notify failed:', err.message);
    }

    // 이슈 #873 — Pro 사용자 + autoAiAnalysisEnabled=true 면 자동 AI 분석 작업 큐 생성.
    //   안전 4중 장치:
    //     1) Firebase Storage 저장은 이미 위에서 완료 (변경 없음)
    //     2) pattern_files 도큐먼트 생성도 이미 완료 (변경 없음)
    //     3) 사용자 Pro 미가입 또는 토글 미설정 시 건너뜀
    //     4) try-catch 외부 감싸기 — 큐 생성 실패해도 본 흐름 정상 종료
    try {
      const userDataLite = userDoc.data() || {};
      const isPro = (userDataLite.subscription?.planId || 'free') === 'pro';
      const dropboxPrivate = await db
        .collection('users').doc(uid)
        .collection('private').doc('dropbox')
        .get();
      const autoAi = dropboxPrivate.exists
        && dropboxPrivate.data()?.autoAiAnalysisEnabled === true;

      if (isPro && autoAi) {
        const jobBatch = db.batch();
        const jobIds = [];
        for (let i = 0; i < uploaded.length; i += 1) {
          const file = uploaded[i];
          // PDF/이미지만 (이미 isAllowedAttachment 통과한 후라 안전).
          const jobRef = db.collection('pending_ai_jobs').doc();
          jobIds.push(jobRef.id);
          jobBatch.set(jobRef, {
            uid,
            storagePath: file.storagePath,
            filename: file.filename,
            mimeType: file.mimeType,
            sizeBytes: file.sizeBytes,
            patternFileId: createdIds[i] || null,
            subject,
            fromEmail: extractEmailAddress(rawFrom) || '',
            source: 'emailInbound',
            status: 'pending',
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
        await jobBatch.commit();
        console.log('[inboundEmail] ai jobs enqueued', { uid, jobIds });
      } else {
        console.log('[inboundEmail] auto AI skipped', { uid, isPro, autoAi });
      }
    } catch (err) {
      console.warn('[inboundEmail] enqueue ai job failed:', err.message);
    }

    console.log('[inboundEmail] success', {
      uid, attachments: uploaded.length, createdIds, from: rawFrom,
    });

    res.status(200).json({
      ok: true,
      uid,
      uploaded: uploaded.length,
      patternFileIds: createdIds,
    });
  },
);

// 사용자가 인입 키를 재발급하고 싶을 때 (스팸 누출 시).
//   - 인증된 본인만 호출 가능.
//   - users/{uid}.inboundEmailKey 를 새 4자 키로 교체 + updatedAt 기록.
//   - 가입 시점에 키가 없는 사용자도 본 함수로 최초 발급.
//   - 이슈 #872: customKey(optional) — 사용자 지정 별명 (3~12자 영숫자).
//     handle 이 unique 이므로 {handle}_{customKey} 도 자동 unique.
exports.regenerateInboundEmailKey = onCall(
  { region: REGION },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError('unauthenticated', '로그인이 필요합니다.');

    const userRef = db.collection('users').doc(uid);
    const snap = await userRef.get();
    if (!snap.exists) {
      throw new HttpsError('not-found', '사용자 정보를 찾을 수 없습니다.');
    }
    const data = snap.data() || {};
    const handle = (data.handle || '').toLowerCase();
    if (!handle) {
      throw new HttpsError('failed-precondition', '핸들(@아이디)을 먼저 설정해 주세요.');
    }

    // 이슈 #872 — 사용자 지정 별명(customKey) 처리.
    const rawCustom = request.data && typeof request.data.customKey === 'string'
      ? request.data.customKey.trim().toLowerCase()
      : '';
    let nextKey;
    if (rawCustom) {
      // 형식 검증
      if (!/^[a-z0-9]{3,12}$/.test(rawCustom)) {
        throw new HttpsError(
          'invalid-argument',
          '별명은 3~12자의 영문 소문자/숫자만 사용할 수 있어요.',
        );
      }
      const currentKey = (data.inboundEmailKey || '').toLowerCase();
      if (rawCustom === currentKey) {
        throw new HttpsError(
          'already-exists',
          '현재 별명과 동일해요. 다른 별명을 입력해 주세요.',
        );
      }
      // 동일 handle + 동일 key 충돌 확인 (handle 이 unique 이므로 사실상 본인 외 발견되면 비정상).
      const dup = await db
        .collection('users')
        .where('handle', '==', handle)
        .where('inboundEmailKey', '==', rawCustom)
        .limit(1)
        .get();
      if (!dup.empty && dup.docs[0].id !== uid) {
        throw new HttpsError(
          'already-exists',
          '이미 사용 중인 별명이에요. 다른 별명을 입력해 주세요.',
        );
      }
      nextKey = rawCustom;
    } else {
      // 충돌 방지 — 동일 (handle, key) 가 다른 uid 에 없는지 확인.
      nextKey = generateInboundEmailKey();
      for (let attempt = 0; attempt < 5; attempt += 1) {
        const dup = await db
          .collection('users')
          .where('handle', '==', handle)
          .where('inboundEmailKey', '==', nextKey)
          .limit(1)
          .get();
        if (dup.empty || (dup.docs[0].id === uid)) break;
        nextKey = generateInboundEmailKey();
      }
    }

    await userRef.set({
      inboundEmailKey: nextKey,
      inboundEmailUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    const domain = process.env.INBOUND_EMAIL_DOMAIN || 'pattern.moriknit.com';
    return {
      handle,
      inboundEmailKey: nextKey,
      inboundEmailAddress: `${handle}_${nextKey}@${domain}`,
    };
  },
);


// ──────────────────────────────────────────────────────────────────────────────
// 이슈 #837 — @moriknit 인박스 Phase 1
//
// 어드민이 사용자에게 시스템 명의(@moriknit)로 답장 + 사용자가 보낸 메시지를
// 어드민이 관리하기 위한 메타 자동 업데이트.
//
// 1) sendAdminReplyAsMoriknit (Callable)
//    - 어드민 권한 검증 → 지정 사용자(@moriknit DM 룸)에 시스템 명의 메시지 추가.
//    - 룸 메타: lastMessage / lastMessageAt 업데이트, unrespondedSince 삭제,
//      unreadByAdmin = 0, unreadCount.{user} += 1.
//    - meta: { sentByAdmin: <admin_uid>, senderType: 'admin_as_system', deepLink? }
//    - 사용자에게 FCM 푸시 전송 (해당 사용자 fcm_tokens).
//
// 2) onUserMessageInMoriknitDm (Firestore Trigger)
//    - dm_rooms/{roomId}/messages/{msgId} write 발생 시 호출.
//    - roomId 가 @moriknit 시스템 봇과의 룸(participants 에 moriknit_uid 포함) 이고
//      senderId 가 사용자(시스템 봇 X) 인 경우에만 메타 업데이트.
//    - lastUserMessageAt = 메시지 시각, unrespondedSince (없으면 set, 있으면 그대로),
//      unreadByAdmin = FieldValue.increment(1).
//    - 어드민 답장에 의해 생성된 메시지(senderType: 'admin_as_system')는 트리거 무시.
// ──────────────────────────────────────────────────────────────────────────────

exports.sendAdminReplyAsMoriknit = onCall(
  { region: REGION },
  async (request) => {
    const uid = request.auth?.uid;
    await assertIsAdmin(uid);

    const data = request.data || {};
    const userUid = (data.userUid || '').toString().trim();
    const text = (data.text || '').toString().trim();
    const deepLink = (data.deepLink || '').toString().trim();
    // 이슈 #845 — 어드민 첨부 (이미지 = imageUrl, 비이미지 = attachmentUrl).
    const imageUrl = (data.imageUrl || '').toString().trim();
    const attachmentUrl = (data.attachmentUrl || '').toString().trim();
    const attachmentName = (data.attachmentName || '').toString().trim();

    if (!userUid) {
      throw new HttpsError('invalid-argument', 'userUid 가 필요합니다.');
    }
    // 이슈 #845 — 본문이 비어도 이미지/파일 첨부가 있으면 발송 허용.
    if (!text && !imageUrl && !attachmentUrl) {
      throw new HttpsError('invalid-argument', '메시지 본문 또는 첨부가 필요합니다.');
    }
    if (userUid === MORIKNIT_SYSTEM_UID) {
      throw new HttpsError('invalid-argument', '시스템 봇 자신에게는 보낼 수 없습니다.');
    }

    await ensureMoriknitSystemUser();

    const roomId = dmRoomIdFor(MORIKNIT_SYSTEM_UID, userUid);
    const roomRef = db.collection('dm_rooms').doc(roomId);
    const msgRef = roomRef.collection('messages').doc();

    // 1) 룸 메타 및 메시지 작성 — 룸 존재 여부에 따라 set/update 분기
    const roomSnap = await roomRef.get();
    const userSnap = await db.collection('users').doc(userUid).get();
    const userData = userSnap.exists ? (userSnap.data() || {}) : {};
    const recipientName = userData.displayName || '';
    const recipientHandle = userData.handle || '';
    const recipientPhoto = userData.photoURL || '';

    // 이슈 #845 — 첨부 보유 시 lastMessage 미리보기는 첨부 라벨로 보강.
    const previewText = text || (imageUrl ? '[이미지]' : (attachmentUrl ? `[파일] ${attachmentName || '첨부'}` : ''));

    const messagePayload = {
      senderId: MORIKNIT_SYSTEM_UID,
      senderName: MORIKNIT_SYSTEM_NAME,
      text,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      readBy: {},
      meta: {
        source: 'admin_reply',
        senderType: 'admin_as_system',
        sentByAdmin: uid,
        deepLink: deepLink || null,
      },
      // 이슈 #845 — 어드민 첨부 필드 (있는 것만 저장).
      ...(imageUrl ? { imageUrl } : {}),
      ...(attachmentUrl ? { attachmentUrl } : {}),
      ...(attachmentName ? { attachmentName } : {}),
    };

    const batch = db.batch();
    batch.set(msgRef, messagePayload);
    if (!roomSnap.exists) {
      batch.set(roomRef, {
        participants: [MORIKNIT_SYSTEM_UID, userUid],
        participantNames: {
          [MORIKNIT_SYSTEM_UID]: MORIKNIT_SYSTEM_NAME,
          [userUid]: recipientName,
        },
        participantHandles: {
          [MORIKNIT_SYSTEM_UID]: MORIKNIT_SYSTEM_HANDLE,
          [userUid]: recipientHandle,
        },
        participantPhotos: {
          [MORIKNIT_SYSTEM_UID]: '',
          [userUid]: recipientPhoto,
        },
        lastMessage: previewText,
        lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
        unreadCount: {
          [MORIKNIT_SYSTEM_UID]: 0,
          [userUid]: 1,
        },
        isSystemChannel: true,
        unreadByAdmin: 0,
      });
    } else {
      batch.update(roomRef, {
        lastMessage: previewText,
        lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
        [`unreadCount.${userUid}`]: admin.firestore.FieldValue.increment(1),
        isSystemChannel: true,
        unreadByAdmin: 0,
        unrespondedSince: admin.firestore.FieldValue.delete(),
      });
    }
    await batch.commit();

    // 2) 사용자에게 FCM 푸시 전송 — fcm_tokens 하위 문서 일괄 조회
    let successCount = 0;
    let failureCount = 0;
    try {
      const tokensSnap = await db
        .collection('users').doc(userUid)
        .collection('fcm_tokens').get();
      const tokens = [];
      const refByToken = new Map();
      tokensSnap.forEach((doc) => {
        const tk = doc.id;
        if (!tk) return;
        tokens.push(tk);
        refByToken.set(tk, doc.ref);
      });
      if (tokens.length > 0) {
        // 이슈 #845 — 본문 비어있어도 첨부 라벨로 푸시 표시.
        const pushBody = previewText.length > 120
          ? `${previewText.slice(0, 117)}...`
          : previewText;
        const notification = {
          title: MORIKNIT_SYSTEM_NAME,
          body: pushBody,
        };
        const dataPayload = {};
        if (deepLink) dataPayload.deepLink = deepLink;
        // 클라이언트가 푸시 → @moriknit DM 화면으로 이동할 수 있도록 roomId 도 포함
        dataPayload.dmRoomId = roomId;
        dataPayload.source = 'admin_reply';

        const messaging = admin.messaging();
        const resp = await messaging.sendEachForMulticast({
          tokens,
          notification,
          data: dataPayload,
          android: {
            priority: 'high',
            notification: { channelId: 'default' },
          },
          apns: { payload: { aps: { sound: 'default' } } },
        });
        successCount = resp.successCount;
        failureCount = resp.failureCount;

        // 무효 토큰 정리
        const invalidRefs = [];
        resp.responses.forEach((r, idx) => {
          if (!r.success) {
            const code = r.error && r.error.code;
            if (
              code === 'messaging/registration-token-not-registered' ||
              code === 'messaging/invalid-argument' ||
              code === 'messaging/invalid-registration-token'
            ) {
              invalidRefs.push(refByToken.get(tokens[idx]));
            }
          }
        });
        if (invalidRefs.length > 0) {
          const pruneBatch = db.batch();
          invalidRefs.forEach((r) => { if (r) pruneBatch.delete(r); });
          try { await pruneBatch.commit(); } catch (_) { /* ignore */ }
        }
      }
    } catch (e) {
      console.warn('[sendAdminReplyAsMoriknit] FCM push failed:', e.message);
    }

    return {
      ok: true,
      messageId: msgRef.id,
      roomId,
      pushSuccessCount: successCount,
      pushFailureCount: failureCount,
    };
  },
);

exports.onUserMessageInMoriknitDm = onDocumentCreated(
  { document: 'dm_rooms/{roomId}/messages/{messageId}', region: REGION },
  async (event) => {
    const roomId = event.params.roomId;
    const snap = event.data;
    if (!snap) return;
    const data = snap.data() || {};
    const senderId = (data.senderId || '').toString();
    // 어드민 답장(senderType: 'admin_as_system') 또는 시스템 봇이 직접 보낸 메시지는 무시
    if (senderId === MORIKNIT_SYSTEM_UID) return;
    const meta = data.meta || {};
    if (meta && (meta.senderType === 'admin_as_system' || meta.source === 'broadcast' || meta.source === 'admin_reply')) {
      return;
    }

    // 룸이 @moriknit 시스템 봇과의 1:1 채널인지 확인
    // deterministic id = sort([moriknit_system, userUid]).join('__')
    if (!roomId.includes(MORIKNIT_SYSTEM_UID)) return;
    const roomRef = db.collection('dm_rooms').doc(roomId);
    const roomSnap = await roomRef.get();
    if (!roomSnap.exists) return;
    const roomData = roomSnap.data() || {};
    const participants = Array.isArray(roomData.participants) ? roomData.participants : [];
    if (!participants.includes(MORIKNIT_SYSTEM_UID)) return;
    if (!participants.includes(senderId)) return; // senderId 가 룸 멤버가 아니면 무시

    // 메타 업데이트 — lastUserMessageAt, unrespondedSince (있으면 보존), unreadByAdmin++
    const now = admin.firestore.FieldValue.serverTimestamp();
    const updates = {
      lastUserMessageAt: now,
      unreadByAdmin: admin.firestore.FieldValue.increment(1),
    };
    if (!roomData.unrespondedSince) {
      updates.unrespondedSince = now;
    }
    try {
      await roomRef.update(updates);
    } catch (e) {
      console.warn('[onUserMessageInMoriknitDm] room meta update failed:', e.message);
    }
  },
);

// ──────────────────────────────────────────────────────────────────────────────
// 일회용 — 사용자 계정 재가입 후 옛 uid 데이터 마이그레이션.
// 호출 완료 후 즉시 함수 삭제 예정. secret token 으로 보호.
// ──────────────────────────────────────────────────────────────────────────────
exports.adminMigrateUserData = onRequest(
  { region: REGION, timeoutSeconds: 540, memory: '512MiB' },
  async (req, res) => {
    const secret = req.query.secret;
    if (secret !== 'koyunsuk-migrate-AoDCY-20260519') {
      res.status(401).send('Forbidden');
      return;
    }
    const oldUid = String(req.query.oldUid || '').trim();
    if (!oldUid) {
      res.status(400).send('oldUid required');
      return;
    }

    let newUid;
    try {
      const userRecord = await admin.auth().getUserByEmail('koyunsuk@gmail.com');
      newUid = userRecord.uid;
    } catch (e) {
      res.status(500).send(`Failed to lookup koyunsuk@gmail.com: ${e.message}`);
      return;
    }

    if (oldUid === newUid) {
      res.json({ status: 'skip', reason: 'oldUid == newUid', newUid });
      return;
    }

    // ownerUid 매핑 추가 — moriknit 의 진짜 owner field 패턴.
    const OWNER_FIELDS_FULL = ['userId', 'ownerId', 'ownerUid', 'createdBy', 'authorId', 'authorUid', 'uid'];
    const targets = [
      { col: 'step_blueprints', fields: OWNER_FIELDS_FULL },
      { col: 'patterns', fields: OWNER_FIELDS_FULL },
      { col: 'swatches', fields: OWNER_FIELDS_FULL },
      { col: 'projects', fields: OWNER_FIELDS_FULL },
      { col: 'counters', fields: OWNER_FIELDS_FULL },
      { col: 'step_runs', fields: OWNER_FIELDS_FULL },
      { col: 'posts', fields: OWNER_FIELDS_FULL },
      { col: 'community_posts', fields: OWNER_FIELDS_FULL },
      { col: 'comments', fields: OWNER_FIELDS_FULL },
      { col: 'bug_reports', fields: OWNER_FIELDS_FULL },
      { col: 'yarn', fields: OWNER_FIELDS_FULL },
      { col: 'accessories', fields: OWNER_FIELDS_FULL },
      { col: 'books', fields: OWNER_FIELDS_FULL },
      { col: 'photo_album', fields: OWNER_FIELDS_FULL },
      { col: 'courses', fields: OWNER_FIELDS_FULL },
      { col: 'tester_feedback', fields: OWNER_FIELDS_FULL },
      { col: 'public_projects', fields: OWNER_FIELDS_FULL },
      { col: 'seller_listings', fields: ['sellerId', ...OWNER_FIELDS_FULL] },
      { col: 'memos', fields: OWNER_FIELDS_FULL },
      { col: 'needles', fields: OWNER_FIELDS_FULL },
      { col: 'favorites', fields: OWNER_FIELDS_FULL },
      { col: 'pattern_sessions', fields: OWNER_FIELDS_FULL },
      { col: 'kal', fields: ['hostId', ...OWNER_FIELDS_FULL] },
      { col: 'pattern_charts', fields: OWNER_FIELDS_FULL },
      { col: 'editorial', fields: OWNER_FIELDS_FULL },
      { col: 'admin_broadcasts', fields: ['sentByUid', ...OWNER_FIELDS_FULL] },
    ];

    const results = {};
    for (const target of targets) {
      let totalMigrated = 0;
      for (const field of target.fields) {
        try {
          const snap = await db
            .collection(target.col)
            .where(field, '==', oldUid)
            .get();
          if (snap.empty) continue;
          let batch = db.batch();
          let count = 0;
          for (const doc of snap.docs) {
            batch.update(doc.ref, { [field]: newUid });
            count++;
            if (count % 400 === 0) {
              await batch.commit();
              batch = db.batch();
            }
          }
          if (count % 400 !== 0) await batch.commit();
          totalMigrated += count;
        } catch (_) {
          // 컬렉션/필드 없으면 무시
        }
      }
      if (totalMigrated > 0) results[target.col] = totalMigrated;
    }

    // users 도큐먼트 머지
    try {
      const oldUserDoc = await db.collection('users').doc(oldUid).get();
      if (oldUserDoc.exists) {
        const oldData = oldUserDoc.data();
        const newUserRef = db.collection('users').doc(newUid);
        const newUserDoc = await newUserRef.get();
        const newData = newUserDoc.exists ? newUserDoc.data() : {};
        const mergedData = {
          ...oldData,
          ...newData,
          handle: newData.handle || oldData.handle || '',
          email: newData.email || oldData.email || '',
          migratedFromUid: oldUid,
          migratedAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        await newUserRef.set(mergedData, { merge: true });
        results.usersDoc = 'merged';
      } else {
        results.usersDoc = 'old user doc not found (이미 삭제됨)';
      }

      // users/{oldUid} 의 모든 서브컬렉션을 자동 탐지하여 일괄 복사.
      //   (pattern_charts, swatches, projects, counters, fcm_tokens 등 모두)
      try {
        const oldUserRef = db.collection('users').doc(oldUid);
        const subCollections = await oldUserRef.listCollections();
        for (const subCol of subCollections) {
          const subColName = subCol.id;
          const oldSnap = await subCol.get();
          if (oldSnap.empty) continue;
          let batch = db.batch();
          let count = 0;
          for (const doc of oldSnap.docs) {
            const newRef = db
              .collection('users')
              .doc(newUid)
              .collection(subColName)
              .doc(doc.id);
            batch.set(newRef, doc.data());
            count++;
            if (count % 400 === 0) {
              await batch.commit();
              batch = db.batch();
            }
          }
          if (count % 400 !== 0) await batch.commit();
          if (count > 0) results[`users/${subColName}`] = count;
        }
      } catch (e) {
        results.subColsError = e.message;
      }
    } catch (e) {
      results.usersError = e.message;
    }

    // step_blueprints 의 ownerUid 가 newUid 인 도큐먼트에서 pattern_charts 재생성.
    //   (옛 user 도큐먼트 삭제 시 users/{uid}/pattern_charts 서브컬렉션도 함께 삭제됨 →
    //   도안 목록 빈 결과. step_blueprints 의 title/id 로 최소 pattern_chart 복원.)
    try {
      const blueprintSnap = await db
        .collection('step_blueprints')
        .where('ownerUid', '==', newUid)
        .get();
      let regenCount = 0;
      let batch = db.batch();
      let batchCount = 0;
      for (const bp of blueprintSnap.docs) {
        const data = bp.data();
        const chartRef = db
          .collection('users')
          .doc(newUid)
          .collection('pattern_charts')
          .doc(bp.id);
        // 기존 pattern_chart 가 있어도 update (이전 호출에서 빈 껍데기로 만든 케이스 보강)
        const imageUrls = Array.isArray(data.attachedImageUrls) ? data.attachedImageUrls : [];
        const pdfUrls = Array.isArray(data.attachedPdfUrls) ? data.attachedPdfUrls : [];
        // PatternChart 모델의 required 필드 (rows/cols/mode/grid) 모두 채워야
        // freezed fromJson 통과. 빈 grid + 1x1 셀로 최소 도큐먼트 구성.
        batch.set(chartRef, {
          id: bp.id,
          title: data.title || data.titleKo || '복구된 도안',
          ownerUid: newUid,
          userId: newUid,
          imageUrl: imageUrls.length > 0 ? imageUrls[0] : '',
          pdfUrl: pdfUrls.length > 0 ? pdfUrls[0] : '',
          rows: 0,
          cols: 0,
          mode: 'symbol',
          grid: [],
          chartType: 'rect',
          visibility: 'private',
          status: 'draft',
          createdAt: data.createdAt || admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: data.updatedAt || admin.firestore.FieldValue.serverTimestamp(),
          restoredFromBlueprint: true,
        });
        regenCount++;
        batchCount++;
        if (batchCount % 400 === 0) {
          await batch.commit();
          batch = db.batch();
        }
      }
      if (batchCount % 400 !== 0 && batchCount > 0) await batch.commit();
      results.regeneratedPatternCharts = regenCount;
    } catch (e) {
      results.regenError = e.message;
    }

    // dm_rooms participants 배열 변경
    try {
      const dmSnap = await db
        .collection('dm_rooms')
        .where('participants', 'array-contains', oldUid)
        .get();
      let count = 0;
      for (const doc of dmSnap.docs) {
        const data = doc.data();
        const participants = (data.participants || []).map((p) => (p === oldUid ? newUid : p));
        const updates = { participants };
        for (const fieldName of ['participantNames', 'participantHandles', 'participantPhotos', 'unreadCount']) {
          if (data[fieldName] && data[fieldName][oldUid] !== undefined) {
            updates[fieldName] = { ...data[fieldName] };
            updates[fieldName][newUid] = updates[fieldName][oldUid];
            delete updates[fieldName][oldUid];
          }
        }
        await doc.ref.update(updates);
        count++;
      }
      if (count > 0) results.dm_rooms = count;
    } catch (e) {
      results.dmRoomsError = e.message;
    }

    res.json({ oldUid, newUid, results, status: 'completed' });
  },
);

// 일회용 — 마이그레이션으로 만들어진 pattern_charts (restoredFromBlueprint=true)
// 일괄 삭제. step_blueprints (마스터 템플릿) 는 보존.
exports.adminCleanupRestoredPatternCharts = onRequest(
  { region: REGION, timeoutSeconds: 540, memory: '512MiB' },
  async (req, res) => {
    const secret = req.query.secret;
    if (secret !== 'koyunsuk-migrate-AoDCY-20260519') {
      res.status(401).send('Forbidden');
      return;
    }
    let uid = String(req.query.uid || '').trim();
    if (!uid) {
      try {
        const userRecord = await admin.auth().getUserByEmail('koyunsuk@gmail.com');
        uid = userRecord.uid;
      } catch (e) {
        res.status(500).send(`uid lookup failed: ${e.message}`);
        return;
      }
    }
    try {
      const snap = await db
        .collection('users')
        .doc(uid)
        .collection('pattern_charts')
        .where('restoredFromBlueprint', '==', true)
        .get();
      let count = 0;
      let batch = db.batch();
      for (const doc of snap.docs) {
        batch.delete(doc.ref);
        count++;
        if (count % 400 === 0) {
          await batch.commit();
          batch = db.batch();
        }
      }
      if (count % 400 !== 0) await batch.commit();
      res.json({ uid, deleted: count, status: 'completed' });
    } catch (e) {
      res.status(500).send(e.message);
    }
  },
);

// ──────────────────────────────────────────────────────────────────────────────
// 이슈 #863 — step_blueprints onUpdate 트리거.
//   AI 처리(또는 사용자 편집)로 청사진의 groups 가 비어 있다가 채워지면,
//   sourcePatternId 가 일치하는 모든 프로젝트의 단계로그를 자동 미러링한다.
//   (Phase 3 — 자동 sync 트리거)
//
// 동작:
//   1) before.groups 가 비어 있거나 unitIds 가 모두 비어 있고
//      after.groups 에 unitIds 가 있는 그룹이 1개 이상이면 진행 (그 외 skip)
//   2) collectionGroup('projects') 로 sourcePatternId == bid 인 프로젝트 검색
//   3) 각 프로젝트에 대해 steps 서브컬렉션이 비어 있을 때만 미러링 (멱등성)
//   4) step_blueprints/{bid}/units 를 로딩하여 group.unitIds 순서대로 결합
//   5) 그룹당 1개 ProjectStep 생성 (note = 각 unit instructionKo 의 불릿 목록)
//   6) 프로젝트 doc 의 totalSteps / completedSteps 갱신
//
// Firestore DB가 asia-northeast3(서울)이므로 트리거 리전도 동일하게 설정.
// ──────────────────────────────────────────────────────────────────────────────
exports.onStepBlueprintGroupsUpdate = onDocumentUpdated(
  { document: 'step_blueprints/{bid}', region: 'asia-northeast3' },
  async (event) => {
    const bid = event.params.bid;
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};

    const beforeGroups = Array.isArray(before.groups) ? before.groups : [];
    const afterGroups = Array.isArray(after.groups) ? after.groups : [];

    const hasNonEmptyGroup = (groups) =>
      groups.some((g) => {
        const ids = Array.isArray(g?.unitIds) ? g.unitIds : [];
        return ids.length > 0;
      });

    const beforeHasUnits = hasNonEmptyGroup(beforeGroups);
    const afterHasUnits = hasNonEmptyGroup(afterGroups);

    // 조건: 이전에는 비어있었고 이제 단위가 채워진 경우에만 sync.
    //   이미 한 번 채워진 청사진의 후속 편집은 기존 프로젝트 단계로그를
    //   덮어쓰지 않는다(사용자 진행 보호). 후속 편집 sync 는 별도 정책으로.
    if (beforeHasUnits || !afterHasUnits) {
      return null;
    }

    console.log(`[onStepBlueprintGroupsUpdate] bid=${bid} groups filled, scanning linked projects...`);

    // 1) sourcePatternId 매칭 프로젝트 검색 (모든 사용자 대상).
    let projectsSnap;
    try {
      projectsSnap = await db
        .collectionGroup('projects')
        .where('sourcePatternId', '==', bid)
        .get();
    } catch (e) {
      console.error(`[onStepBlueprintGroupsUpdate] collectionGroup query failed: ${e?.message}`);
      return null;
    }

    if (projectsSnap.empty) {
      console.log(`[onStepBlueprintGroupsUpdate] bid=${bid}: no linked projects, skip.`);
      return null;
    }

    // 2) units 로딩 (한 번만).
    const unitsSnap = await db
      .collection('step_blueprints')
      .doc(bid)
      .collection('units')
      .get();
    const unitsById = new Map();
    for (const u of unitsSnap.docs) {
      unitsById.set(u.id, { id: u.id, ...u.data() });
    }

    if (unitsById.size === 0) {
      console.log(`[onStepBlueprintGroupsUpdate] bid=${bid}: groups present but no units, skip.`);
      return null;
    }

    // 3) groups order 기준 정렬.
    const sortedGroups = [...afterGroups].sort(
      (a, b) => (a?.order ?? 0) - (b?.order ?? 0),
    );

    const rowRegex = /(\d+)\s*(단|Row|row|행)/gi;
    const estimateRows = (texts) => {
      let maxRow = 0;
      for (const t of texts) {
        if (!t) continue;
        let m;
        rowRegex.lastIndex = 0;
        while ((m = rowRegex.exec(t)) !== null) {
          const n = parseInt(m[1], 10);
          if (!Number.isNaN(n) && n > maxRow) maxRow = n;
        }
      }
      return maxRow;
    };

    let syncedCount = 0;
    let skippedCount = 0;
    const errors = [];

    // 4) 각 프로젝트 sync.
    for (const projectDoc of projectsSnap.docs) {
      const projectRef = projectDoc.ref;
      const projectId = projectDoc.id;

      try {
        // 멱등성: 이미 단계가 있는 프로젝트는 건너뜀.
        const existingSteps = await projectRef
          .collection('steps')
          .limit(1)
          .get();
        if (!existingSteps.empty) {
          skippedCount++;
          continue;
        }

        // step 문서 생성 (그룹당 1개).
        const batch = db.batch();
        let order = 0;
        const nowIso = new Date().toISOString();
        for (const group of sortedGroups) {
          const groupUnitIds = Array.isArray(group?.unitIds) ? group.unitIds : [];
          if (groupUnitIds.length === 0) continue;

          const noteLines = [];
          const textsForRowEstimate = [];
          for (const uid of groupUnitIds) {
            const u = unitsById.get(uid);
            if (!u) continue;
            const text =
              (u.instructionKo && String(u.instructionKo).trim()) ||
              (u.instruction && String(u.instruction).trim()) ||
              (u.instructionEn && String(u.instructionEn).trim()) ||
              '';
            if (text) {
              noteLines.push(`• ${text}`);
              textsForRowEstimate.push(text);
            }
          }
          if (noteLines.length === 0) continue;

          const title =
            (group.titleKo && String(group.titleKo).trim()) ||
            (group.title && String(group.title).trim()) ||
            `섹션 ${order + 1}`;

          const estimatedRows = estimateRows(textsForRowEstimate);

          const stepRef = projectRef.collection('steps').doc();
          batch.set(stepRef, {
            name: title,
            description: '',
            isDone: false,
            note: noteLines.join('\n'),
            order: order,
            photoUrl: null,
            targetRow: estimatedRows,
            blockType: 'text',
            createdAt: nowIso,
            doneAt: null,
            sourceSectionId: group.id || '',
            sourcePatternChartId: bid,
          });
          order++;
        }

        if (order === 0) {
          skippedCount++;
          continue;
        }

        // 프로젝트 totalSteps/completedSteps 갱신.
        batch.update(projectRef, {
          totalSteps: order,
          completedSteps: 0,
        });

        await batch.commit();
        syncedCount++;
      } catch (e) {
        errors.push({ projectId, error: e?.message || String(e) });
      }
    }

    console.log(
      `[onStepBlueprintGroupsUpdate] bid=${bid} done. ` +
        `synced=${syncedCount} skipped=${skippedCount} errors=${errors.length}`,
    );
    if (errors.length > 0) {
      console.error('[onStepBlueprintGroupsUpdate] errors:', JSON.stringify(errors));
    }
    return null;
  },
);


// ──────────────────────────────────────────────────────────────────────────────
// 이슈 #873 — onAiJobCreated
//   Firestore Trigger: pending_ai_jobs/{jobId} 문서 생성 시 자동 실행.
//   흐름:
//     1) status='processing' 로 마킹 + 사용자 토글/Pro 재검증
//     2) Storage 에서 PDF/이미지 다운로드 (크기 10MB 초과 또는 PDF 30페이지 초과 시 skip)
//     3) runAiPatternAnalysis(Haiku) → aiSections 반환
//     4) users/{uid}/pattern_charts/{auto} 저장
//        - sourceType: 'aiConverted', status: 'complete',
//          restoredFromInbound: true, autoAiAnalysis: true, filename, pdfUrl=storagePath
//     5) step_blueprints/{chartId} 저장 (ownerUid, title, visibility='draft')
//        + step_blueprints/{chartId}/units 에 step 단위 일괄 생성
//     6) status='completed' 마킹 + 사용자 FCM 푸시 알림 (best-effort)
//   실패 시: status='failed' + error 메시지 기록 (사용자 도안 라이브러리에 추가되지 않음).
//   PDF 30페이지 초과 시: status='skipped_too_large' + 사용자 알림 없음.
// ──────────────────────────────────────────────────────────────────────────────

// 단순 휴리스틱 PDF 페이지 카운터 (외부 의존 X).
//   /Type /Page 또는 /Type/Page 출현 횟수 - 일반 PDF 에서 양호한 추정치.
//   정밀하지 않아도 30 페이지 가드 용도로 충분.
function estimatePdfPageCount(buffer) {
  try {
    const text = buffer.toString('latin1');
    const re = /\/Type\s*\/Page[^s]/g;
    const matches = text.match(re);
    return matches ? matches.length : 0;
  } catch (_) {
    return 0;
  }
}

exports.onAiJobCreated = onDocumentCreated(
  {
    document: 'pending_ai_jobs/{jobId}',
    region: REGION,
    secrets: [anthropicApiKey],
    timeoutSeconds: 540,
    memory: '1GiB',
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return null;
    const job = snap.data() || {};
    const { uid, storagePath, filename, mimeType } = job;
    const jobRef = snap.ref;

    if (!uid || !storagePath || !mimeType) {
      console.warn('[onAiJobCreated] missing fields', { uid, storagePath, mimeType });
      await jobRef.update({
        status: 'failed',
        error: 'missing required fields (uid/storagePath/mimeType)',
        failedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return null;
    }

    // 0) 사용자 Pro + 토글 재검증 (인입 시점 이후 변동 가능).
    try {
      const userSnap = await db.collection('users').doc(uid).get();
      const isPro = (userSnap.data()?.subscription?.planId || 'free') === 'pro';
      const priv = await db.collection('users').doc(uid)
        .collection('private').doc('dropbox').get();
      const autoAi = priv.exists && priv.data()?.autoAiAnalysisEnabled === true;
      if (!isPro || !autoAi) {
        await jobRef.update({
          status: 'skipped_not_eligible',
          reason: isPro ? 'auto_ai_off' : 'not_pro',
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log('[onAiJobCreated] skipped not eligible', { uid, isPro, autoAi });
        return null;
      }
    } catch (err) {
      console.warn('[onAiJobCreated] eligibility check failed:', err.message);
      // 계속 진행 (best-effort).
    }

    // 1) processing 마킹.
    try {
      await jobRef.update({
        status: 'processing',
        startedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (_) {/* ignore */}

    // 2) Storage 다운로드 + 크기/페이지 가드.
    const bucket = admin.storage().bucket();
    const fileRef = bucket.file(storagePath);
    let fileBuffer;
    try {
      const [metadata] = await fileRef.getMetadata();
      const fileSize = parseInt(metadata.size, 10);
      if (fileSize > 10 * 1024 * 1024) {
        await jobRef.update({
          status: 'skipped_too_large',
          reason: `file size ${fileSize} > 10MB`,
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log('[onAiJobCreated] skipped too large', { uid, fileSize });
        return null;
      }
      [fileBuffer] = await fileRef.download();
    } catch (err) {
      console.error('[onAiJobCreated] download failed:', err.message);
      await jobRef.update({
        status: 'failed',
        error: `download failed: ${err.message}`,
        failedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return null;
    }

    if (mimeType === 'application/pdf') {
      const pageCount = estimatePdfPageCount(fileBuffer);
      if (pageCount > 30) {
        await jobRef.update({
          status: 'skipped_too_large',
          reason: `pdf pages ~${pageCount} > 30`,
          pdfPageEstimate: pageCount,
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log('[onAiJobCreated] skipped too many pages', { uid, pageCount });
        return null;
      }
    }

    // 3) Haiku 분석 (한국어 번역 포함 기본).
    let parsed;
    try {
      parsed = await runAiPatternAnalysis({
        fileBuffer,
        mimeType,
        needsKorean: true,
        model: 'claude-3-haiku-20240307',
      });
    } catch (err) {
      console.error('[onAiJobCreated] analysis failed:', err.message);
      await jobRef.update({
        status: 'failed',
        error: err.message || 'analysis failed',
        failedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return null;
    }

    const rawSections = Array.isArray(parsed?.sections) ? parsed.sections : [];
    const aiSections = rawSections.map((s, gi) => ({
      id: s.id || `section_${gi + 1}`,
      title: s.title || `Section ${gi + 1}`,
      titleKo: s.titleKo || '',
      steps: (Array.isArray(s.steps) ? s.steps : []).map((step, si) => ({
        id: step.id || `step_${gi + 1}_${si + 1}`,
        instruction: step.instruction || '',
        instructionKo: step.instructionKo || '',
        isCompleted: false,
      })),
    }));

    // 4) pattern_charts 저장 (PatternChart.fromJson 호환 schema).
    //    aiSections 는 pattern_charts 에는 빈 배열 (#687 — 단계는 step_blueprints/units).
    const chartRef = db.collection('users').doc(uid)
      .collection('pattern_charts').doc();
    const chartId = chartRef.id;
    const title = (parsed?.title || filename || 'Untitled').toString().slice(0, 200);

    try {
      await chartRef.set({
        id: chartId,
        title,
        rows: 0,
        cols: 0,
        mode: 'symbol',
        grid: [],
        narrativeText: '',
        type: 'pdf',
        sourceType: 'aiConverted',
        pdfUrl: storagePath,
        imageUrl: '',
        aiSections: [],
        status: 'complete',
        restoredFromInbound: true,
        autoAiAnalysis: true,
        sourceFilename: filename,
        materials: parsed?.materials || '',
        gauge: parsed?.gauge || '',
        sizes: parsed?.sizes || '',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (err) {
      console.error('[onAiJobCreated] pattern_charts save failed:', err.message);
      await jobRef.update({
        status: 'failed',
        error: `chart save failed: ${err.message}`,
        failedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return null;
    }

    // 5) step_blueprints + units 동시 저장 (#687 — 단계 영역 분리).
    try {
      const blueprintRef = db.collection('step_blueprints').doc(chartId);
      await blueprintRef.set({
        id: chartId,
        ownerUid: uid,
        title,
        visibility: 'draft',
        forkable: false,
        memberCount: 0,
        members: {},
        forkCount: 0,
        groups: aiSections.map((sec, gi) => ({
          id: sec.id,
          title: sec.titleKo || sec.title,
          order: gi,
        })),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      const unitsCol = blueprintRef.collection('units');
      // 500 limit batch — 일반 도안은 충분히 안전.
      const unitBatch = db.batch();
      let order = 0;
      for (const sec of aiSections) {
        for (const step of sec.steps) {
          const unitRef = unitsCol.doc(step.id);
          unitBatch.set(unitRef, {
            id: step.id,
            blueprintId: chartId,
            order: order++,
            title: '',
            instruction: step.instruction,
            instructionKo: step.instructionKo,
            groupId: sec.id,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      }
      await unitBatch.commit();
    } catch (err) {
      // blueprint 실패는 치명적이지 않음 — 다음 진입 시 adaptFromPatternChart 폴백.
      console.warn('[onAiJobCreated] blueprint mirror failed:', err.message);
    }

    // 6) job 완료 마킹.
    await jobRef.update({
      status: 'completed',
      chartId,
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 7) FCM 푸시 (best-effort).
    try {
      const tokensSnap = await db.collection('users').doc(uid)
        .collection('fcm_tokens').get();
      const tokens = tokensSnap.docs.map((d) => d.id).filter(Boolean);
      if (tokens.length > 0) {
        const body = filename
          ? `'${filename}' 이(가) 자동으로 라이브러리에 등록됐어요.`
          : '새 도안이 자동으로 라이브러리에 등록됐어요.';
        await admin.messaging().sendEachForMulticast({
          tokens,
          notification: { title: '새 도안 자동 등록됨', body },
          data: {
            deepLink: '/patterns/' + chartId,
            chartId,
            source: 'autoAiAnalysis',
          },
          android: {
            priority: 'high',
            notification: { channelId: 'default' },
          },
          apns: { payload: { aps: { sound: 'default' } } },
        });
      }
    } catch (err) {
      console.warn('[onAiJobCreated] push notify failed:', err.message);
    }

    console.log('[onAiJobCreated] done', {
      uid, chartId, sections: aiSections.length,
      steps: aiSections.reduce((a, s) => a + s.steps.length, 0),
    });
    return null;
  },
);
