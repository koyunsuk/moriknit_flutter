/**
 * Firestore encyclopedia 전체 삭제 스크립트
 * Run: node functions/delete_encyclopedia.js
 */

const https = require('https');
const path = require('path');
const os = require('os');
const fs = require('fs');

const PROJECT_ID = 'moriknit-ceea9';
const COLLECTION = 'encyclopedia';

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

async function listDocs(token, pageToken) {
  let qs = '?pageSize=300';
  if (pageToken) qs += `&pageToken=${pageToken}`;
  const res = await httpsReq('GET',
    'firestore.googleapis.com',
    `/v1/projects/${PROJECT_ID}/databases/(default)/documents/${COLLECTION}${qs}`,
    null,
    { Authorization: `Bearer ${token}` }
  );
  console.log('listDocs status:', res.status, 'docs:', res.body.documents?.length ?? 0);
  return res.body;
}

async function deleteDoc(token, name) {
  await httpsReq('DELETE',
    'firestore.googleapis.com',
    `/v1/${name}`,
    null,
    { Authorization: `Bearer ${token}` }
  );
}

async function main() {
  const token = await getAccessToken();
  console.log('토큰 획득 완료');

  let total = 0;
  let pageToken;

  do {
    const result = await listDocs(token, pageToken);
    const docs = result.documents || [];
    pageToken = result.nextPageToken;

    for (const doc of docs) {
      await deleteDoc(token, doc.name);
      total++;
      process.stdout.write(`\r삭제 중... ${total}개`);
    }
  } while (pageToken);

  console.log(`\n완료: 총 ${total}개 삭제됨`);
}

main().catch(console.error);
