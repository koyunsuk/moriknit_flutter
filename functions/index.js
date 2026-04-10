const crypto = require('crypto');
const admin = require('firebase-admin');
const { onRequest } = require('firebase-functions/v2/https');
const { onDocumentCreated, onDocumentDeleted } = require('firebase-functions/v2/firestore');
const { defineSecret } = require('firebase-functions/params');

admin.initializeApp();

const db = admin.firestore();

const REGION = 'us-central1';
const PROJECT_ID =
  process.env.GCLOUD_PROJECT ||
  JSON.parse(process.env.FIREBASE_CONFIG || '{}').projectId ||
  'moriknit-ceea9';

const RAVELRY_CLIENT_ID = 'e87a14a430bd98b1d5dcb3e851ce8a3d';
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
  const url = new URL(`${RAVELRY_API_BASE}${path}`);
  if (query) {
    Object.entries(query).forEach(([key, value]) => {
      if (value != null) url.searchParams.set(key, String(value));
    });
  }

  const response = await fetch(url, {
    headers: {
      Authorization: `Bearer ${accessToken}`,
      Accept: 'application/json',
    },
  });

  const text = await response.text();
  if (!response.ok) {
    throw new Error(
      `Ravelry API failed (${response.status}) for ${url.pathname}${url.search}: ${text}`,
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
        { path: `/people/${username}/library.json`, query: { page_size: 50 } },
        { path: `/people/${username}/library/search.json`, query: { page_size: 50 } },
        { path: `/people/${username}/library/volumes.json`, query: { page_size: 50 } },
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

// ── 카카오 커스텀 토큰 발급 ─────────────────────────────────
exports.kakaoCustomToken = onRequest(
  { region: REGION },
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
