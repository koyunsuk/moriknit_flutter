/**
 * encyclopedia 컬렉션 category 필드 일괄 업데이트
 * - referenceUrl이 있는 항목 → category: 'symbol'
 * - referenceUrl이 없는 항목 → category: 'term'
 * Run: node functions/update_encyclopedia_categories.js
 */

const https = require('https');
const path = require('path');
const os = require('os');
const fs = require('fs');

const PROJECT_ID = 'moriknit-ceea9';
const COLLECTION = 'encyclopedia';

const configPath = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
const firebaseConfig = JSON.parse(fs.readFileSync(configPath, 'utf8'));

async function getAccessToken() {
  const body = JSON.stringify({
    client_id: '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
    client_secret: 'j9iVZfS8kkCEFUPaAeJV0sAi',
    refresh_token: firebaseConfig.tokens.refresh_token,
    grant_type: 'refresh_token',
  });
  return new Promise((resolve, reject) => {
    const req = https.request(
      { hostname: 'oauth2.googleapis.com', path: '/token', method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body) } },
      (res) => { let d = ''; res.on('data', (c) => (d += c)); res.on('end', () => { const r = JSON.parse(d); if (!r.access_token) throw new Error(d); resolve(r.access_token); }); }
    );
    req.on('error', reject); req.write(body); req.end();
  });
}

async function httpsGet(hostname, urlPath, headers = {}) {
  return new Promise((resolve, reject) => {
    const req = https.request({ hostname, path: urlPath, method: 'GET', headers }, (res) => {
      let d = ''; res.on('data', (c) => (d += c)); res.on('end', () => resolve({ status: res.statusCode, body: d }));
    });
    req.on('error', reject); req.end();
  });
}

async function httpsPatch(hostname, urlPath, body, headers = {}) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(body);
    const req = https.request(
      { hostname, path: urlPath, method: 'PATCH',
        headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(data), ...headers } },
      (res) => { let d = ''; res.on('data', (c) => (d += c)); res.on('end', () => resolve({ status: res.statusCode, body: d })); }
    );
    req.on('error', reject); req.write(data); req.end();
  });
}

async function getAllDocs(token) {
  let allDocs = [];
  let pageToken = null;
  do {
    let urlPath = `/v1/projects/${PROJECT_ID}/databases/(default)/documents/${COLLECTION}?pageSize=300`;
    if (pageToken) urlPath += `&pageToken=${pageToken}`;
    const res = await httpsGet('firestore.googleapis.com', urlPath, { Authorization: `Bearer ${token}` });
    const data = JSON.parse(res.body);
    if (data.documents) allDocs = allDocs.concat(data.documents);
    pageToken = data.nextPageToken || null;
  } while (pageToken);
  return allDocs;
}

async function run() {
  console.log('🔑 토큰 갱신 중...');
  const token = await getAccessToken();
  console.log('✅ 토큰 갱신 완료\n');

  console.log('📄 encyclopedia 전체 항목 조회 중...');
  const allDocs = await getAllDocs(token);
  console.log(`  → 총 ${allDocs.length}개 항목\n`);

  let symbolCount = 0, termCount = 0, skipped = 0;

  for (const doc of allDocs) {
    const refUrl = doc.fields?.referenceUrl?.stringValue || '';
    const currentCategory = doc.fields?.category?.stringValue || '';
    const newCategory = refUrl.length > 0 ? 'symbol' : 'term';

    if (currentCategory === newCategory) {
      skipped++;
      continue;
    }

    const urlPath = `/v1/${doc.name}?updateMask.fieldPaths=category`;
    const body = { fields: { category: { stringValue: newCategory } } };
    const res = await httpsPatch('firestore.googleapis.com', urlPath, body, { Authorization: `Bearer ${token}` });

    const abbr = doc.fields?.abbreviation?.stringValue || doc.fields?.term?.stringValue || doc.name.split('/').pop();
    if (res.status === 200) {
      if (newCategory === 'symbol') {
        console.log(`  🔵 [기호] ${abbr}`);
        symbolCount++;
      } else {
        termCount++;
      }
    } else {
      console.error(`  ❌ [${abbr}] 실패 status=${res.status}`);
    }
  }

  console.log(`\n완료:`);
  console.log(`  기호(symbol) 분류: ${symbolCount}개`);
  console.log(`  용어(term) 분류: ${termCount}개`);
  console.log(`  스킵(변경없음): ${skipped}개`);
}

run().catch((err) => { console.error('오류:', err); process.exit(1); });
