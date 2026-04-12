/**
 * Firestore 컬렉션 목록 확인 스크립트
 * Run: node functions/list_collections.js
 */

const https = require('https');
const path = require('path');
const os = require('os');
const fs = require('fs');

const PROJECT_ID = 'moriknit-ceea9';

const configPath = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
const firebaseConfig = JSON.parse(fs.readFileSync(configPath, 'utf8'));

function httpsReq(method, hostname, reqPath, body, headers) {
  return new Promise((resolve, reject) => {
    const data = body ? JSON.stringify(body) : '';
    const req = https.request(
      { hostname, path: reqPath, method, headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(data), ...headers } },
      (res) => {
        let d = '';
        res.on('data', (c) => d += c);
        res.on('end', () => resolve({ status: res.statusCode, body: d ? JSON.parse(d) : {} }));
      }
    );
    req.on('error', reject);
    if (data) req.write(data);
    req.end();
  });
}

async function getAccessToken() {
  const result = await httpsReq('POST', 'oauth2.googleapis.com', '/token', {
    client_id: '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
    client_secret: 'j9iVZfS8kkCEFUPaAeJV0sAi',
    refresh_token: firebaseConfig.tokens.refresh_token,
    grant_type: 'refresh_token',
  }, {});
  if (!result.body.access_token) throw new Error(`Token refresh failed: ${JSON.stringify(result.body)}`);
  return result.body.access_token;
}

async function listRootCollections(token) {
  const res = await httpsReq('POST',
    'firestore.googleapis.com',
    `/v1/projects/${PROJECT_ID}/databases/(default)/documents:listCollectionIds`,
    {},
    { Authorization: `Bearer ${token}` }
  );
  return res.body.collectionIds || [];
}

async function countDocs(token, collection) {
  const res = await httpsReq('GET',
    'firestore.googleapis.com',
    `/v1/projects/${PROJECT_ID}/databases/(default)/documents/${collection}?pageSize=300`,
    null,
    { Authorization: `Bearer ${token}` }
  );
  return res.body.documents?.length ?? 0;
}

async function main() {
  const token = await getAccessToken();
  const collections = await listRootCollections(token);

  console.log('\n=== Firestore 컬렉션 목록 ===');

  // 브랜드 관련 컬렉션 필터
  const brandCollections = collections.filter(c =>
    c.includes('brand') || c.includes('yarn') || c.includes('needle')
  );

  console.log('\n[브랜드 관련]');
  for (const col of brandCollections) {
    const count = await countDocs(token, col);
    console.log(`  ${col}: ${count}개`);
  }

  console.log('\n[전체 컬렉션]');
  for (const col of collections) {
    console.log(`  - ${col}`);
  }
}

main().catch(console.error);
