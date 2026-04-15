/**
 * Firebase Storage /crochet_symbols/ 파일 목록 조회 →
 * Firestore encyclopedia 코바늘 항목에 referenceUrl 일괄 업데이트
 * Run: node functions/update_crochet_svg_urls.js
 */

const https = require('https');
const path = require('path');
const os = require('os');
const fs = require('fs');

const PROJECT_ID = 'moriknit-ceea9';
const BUCKET = 'moriknit-ceea9.firebasestorage.app';
const SVG_PREFIX = 'crochet_symbols/';
const COLLECTION = 'encyclopedia';

const configPath = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
const firebaseConfig = JSON.parse(fs.readFileSync(configPath, 'utf8'));

function httpsGet(hostname, urlPath, headers = {}) {
  return new Promise((resolve, reject) => {
    const req = https.request({ hostname, path: urlPath, method: 'GET', headers }, (res) => {
      let d = '';
      res.on('data', (c) => (d += c));
      res.on('end', () => resolve({ status: res.statusCode, body: d }));
    });
    req.on('error', reject);
    req.end();
  });
}

function httpsPatch(hostname, urlPath, body, headers = {}) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(body);
    const req = https.request(
      { hostname, path: urlPath, method: 'PATCH', headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(data), ...headers } },
      (res) => { let d = ''; res.on('data', (c) => (d += c)); res.on('end', () => resolve({ status: res.statusCode, body: d })); }
    );
    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

async function getAccessToken() {
  const result = await new Promise((resolve, reject) => {
    const body = JSON.stringify({
      client_id: '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
      client_secret: 'j9iVZfS8kkCEFUPaAeJV0sAi',
      refresh_token: firebaseConfig.tokens.refresh_token,
      grant_type: 'refresh_token',
    });
    const req = https.request(
      { hostname: 'oauth2.googleapis.com', path: '/token', method: 'POST', headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body) } },
      (res) => { let d = ''; res.on('data', (c) => (d += c)); res.on('end', () => resolve(JSON.parse(d))); }
    );
    req.on('error', reject);
    req.write(body);
    req.end();
  });
  if (!result.access_token) throw new Error(`Token refresh failed: ${JSON.stringify(result)}`);
  return result.access_token;
}

// Firebase Storage REST API로 /crochet_symbols/ 파일 목록 + 다운로드 URL 생성
async function listStorageFiles(token) {
  const encodedPrefix = encodeURIComponent(SVG_PREFIX);
  const urlPath = `/v0/b/${BUCKET}/o?prefix=${encodedPrefix}&maxResults=500`;
  const res = await httpsGet('firebasestorage.googleapis.com', urlPath, { Authorization: `Bearer ${token}` });
  const data = JSON.parse(res.body);
  if (!data.items) {
    console.log('파일 없음 또는 오류:', res.body.slice(0, 300));
    return [];
  }
  // 다운로드 URL 형식: https://firebasestorage.googleapis.com/v0/b/{bucket}/o/{encodedPath}?alt=media
  return data.items.map((item) => ({
    name: item.name, // e.g. "crochet_symbols/ch.svg"
    fileName: path.basename(item.name, '.svg'), // e.g. "ch"
    downloadUrl: `https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/${encodeURIComponent(item.name)}?alt=media`,
  }));
}

// Firestore에서 encyclopedia 전체 조회 후 craftType=crochet 필터
async function getCrochetEntries(token) {
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

  return allDocs
    .filter((doc) => doc.fields?.craftType?.stringValue === 'crochet')
    .map((doc) => ({
      name: doc.name,
      docId: doc.name.split('/').pop(),
      abbreviation: (doc.fields?.abbreviation?.stringValue || '').toLowerCase(),
      term: (doc.fields?.term?.stringValue || '').toLowerCase(),
      symbol: (doc.fields?.symbol?.stringValue || '').toLowerCase(),
      currentRefUrl: doc.fields?.referenceUrl?.stringValue || '',
    }));
}

// Firestore 문서 referenceUrl 필드 업데이트
async function updateReferenceUrl(token, docPath, url) {
  const urlPath = `/v1/${docPath}?updateMask.fieldPaths=referenceUrl`;
  const body = { fields: { referenceUrl: { stringValue: url } } };
  return httpsPatch('firestore.googleapis.com', urlPath, body, { Authorization: `Bearer ${token}` });
}

async function run() {
  console.log('🔑 토큰 갱신 중...');
  const token = await getAccessToken();
  console.log('✅ 토큰 갱신 완료\n');

  console.log('📦 Firebase Storage /crochet_symbols/ 파일 목록 조회 중...');
  const svgFiles = await listStorageFiles(token);
  console.log(`  → ${svgFiles.length}개 SVG 파일 발견`);
  svgFiles.forEach((f) => console.log(`     ${f.fileName}.svg → ${f.downloadUrl}`));

  console.log('\n📄 Firestore 코바늘 항목 조회 중...');
  const entries = await getCrochetEntries(token);
  console.log(`  → ${entries.length}개 항목 발견\n`);

  // 수동 매핑: abbreviation → SVG 파일명
  const manualMap = {
    'ch':         'chain',
    '3dc-cl':     'cluster_dc',
    'puff':       'puff_hdc',
    'crossed dc': 'crossed_dc',
    'mr':         'magic_ring',
    'sh':         'shell_dc',
    'join':       'joining_bar',
    'sl st':      'slipstitch',
    'picot':      'ch3_picot',
    'pc':         'popcorn_dc',
  };

  let updated = 0;
  let skipped = 0;
  let notFound = 0;

  for (const entry of entries) {
    // 자동 매핑: abbreviation, symbol, term과 정확히 일치하는 파일
    // 수동 매핑: manualMap에서 파일명 찾기
    const manualFileName = manualMap[entry.abbreviation] || manualMap[entry.term];
    const match = svgFiles.find(
      (f) =>
        f.fileName === entry.abbreviation ||
        f.fileName === entry.symbol ||
        f.fileName === entry.term ||
        (manualFileName && f.fileName === manualFileName)
    );

    if (!match) {
      console.log(`  ⚠️  [${entry.docId}] abbr="${entry.abbreviation}" symbol="${entry.symbol}" → SVG 파일 없음`);
      notFound++;
      continue;
    }

    if (entry.currentRefUrl === match.downloadUrl) {
      skipped++;
      continue;
    }

    const res = await updateReferenceUrl(token, entry.name, match.downloadUrl);
    if (res.status === 200) {
      console.log(`  ✅ [${entry.abbreviation || entry.term}] → ${match.fileName}.svg 연결`);
      updated++;
    } else {
      console.error(`  ❌ [${entry.docId}] 업데이트 실패 status=${res.status}`, res.body.slice(0, 200));
    }
  }

  console.log(`\n완료: 업데이트 ${updated}개, 스킵(이미 설정) ${skipped}개, SVG 없음 ${notFound}개`);
}

run().catch((err) => { console.error('오류:', err); process.exit(1); });
