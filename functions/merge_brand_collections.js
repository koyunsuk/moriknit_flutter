/**
 * Firestore 브랜드 컬렉션 병합 스크립트
 * needleBrands → needle_brands
 * yarnBrands → yarn_brands
 *
 * Run: node functions/merge_brand_collections.js
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
        res.on('end', () => {
          try { resolve({ status: res.statusCode, body: d ? JSON.parse(d) : {} }); }
          catch (e) { resolve({ status: res.statusCode, body: {} }); }
        });
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

async function getAllDocs(token, collection) {
  let docs = [];
  let pageToken;
  do {
    let qs = '?pageSize=300';
    if (pageToken) qs += `&pageToken=${pageToken}`;
    const res = await httpsReq('GET',
      'firestore.googleapis.com',
      `/v1/projects/${PROJECT_ID}/databases/(default)/documents/${collection}${qs}`,
      null,
      { Authorization: `Bearer ${token}` }
    );
    docs = docs.concat(res.body.documents || []);
    pageToken = res.body.nextPageToken;
  } while (pageToken);
  return docs;
}

async function docExists(token, collection, docId) {
  const res = await httpsReq('GET',
    'firestore.googleapis.com',
    `/v1/projects/${PROJECT_ID}/databases/(default)/documents/${collection}/${docId}`,
    null,
    { Authorization: `Bearer ${token}` }
  );
  return res.status === 200;
}

async function writeDoc(token, collection, docId, fields) {
  const res = await httpsReq('PATCH',
    'firestore.googleapis.com',
    `/v1/projects/${PROJECT_ID}/databases/(default)/documents/${collection}/${docId}`,
    { fields },
    { Authorization: `Bearer ${token}` }
  );
  return res.status;
}

async function deleteDoc(token, name) {
  await httpsReq('DELETE',
    'firestore.googleapis.com',
    `/v1/${name}`,
    null,
    { Authorization: `Bearer ${token}` }
  );
}

async function mergeCollections(token, srcCollection, dstCollection) {
  console.log(`\n[${srcCollection}] → [${dstCollection}] 병합 시작...`);

  const srcDocs = await getAllDocs(token, srcCollection);
  console.log(`  소스 문서: ${srcDocs.length}개`);

  let moved = 0, skipped = 0, deleted = 0;

  for (const doc of srcDocs) {
    const docId = doc.name.split('/').pop();
    const exists = await docExists(token, dstCollection, docId);

    if (!exists) {
      await writeDoc(token, dstCollection, docId, doc.fields);
      moved++;
      console.log(`  ✓ 이동: ${docId}`);
    } else {
      skipped++;
      console.log(`  - 스킵(이미 존재): ${docId}`);
    }

    // 소스 문서 삭제
    await deleteDoc(token, doc.name);
    deleted++;
  }

  console.log(`  완료: ${moved}개 이동, ${skipped}개 스킵, ${deleted}개 원본 삭제`);
}

async function main() {
  const token = await getAccessToken();
  console.log('토큰 획득 완료');

  await mergeCollections(token, 'needleBrands', 'needle_brands');
  await mergeCollections(token, 'yarnBrands', 'yarn_brands');

  console.log('\n✅ 모든 병합 완료');
}

main().catch(console.error);
