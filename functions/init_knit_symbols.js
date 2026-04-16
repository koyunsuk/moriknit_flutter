/**
 * Firebase Storage /knit_symbols/ 파일 목록 조회 →
 * Firestore knit_symbols 컬렉션에 메타데이터 포함 문서 생성
 *
 * Run: node functions/init_knit_symbols.js
 *
 * 스키마:
 *   id, name(한국어), nameEn, abbreviation, svgUrl,
 *   category(basic|decrease|increase|cable|special),
 *   spanWidth(기본1), spanHeight(기본1), order
 */

const https = require('https');
const path = require('path');
const os = require('os');
const fs = require('fs');

const PROJECT_ID = 'moriknit-ceea9';
const BUCKET = 'moriknit-ceea9.firebasestorage.app';
const SVG_PREFIX = 'knit_symbols/';
const COLLECTION = 'knit_symbols';

const configPath = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
const firebaseConfig = JSON.parse(fs.readFileSync(configPath, 'utf8'));

// ── 파일명 → 메타데이터 매핑 ──────────────────────────────────────────────
const SYMBOL_META = {
  // basic
  'knit':               { name: '겉뜨기',           nameEn: 'Knit',                  abbr: 'K',       category: 'basic',    order: 1  },
  'purl':               { name: '안뜨기',            nameEn: 'Purl',                  abbr: 'P',       category: 'basic',    order: 2  },
  'yarnover':           { name: '바늘비우기',         nameEn: 'Yarn Over',             abbr: 'YO',      category: 'basic',    order: 3  },
  'yarnovertwist':      { name: '바늘비우기꼬기',     nameEn: 'Yarn Over Twist',       abbr: 'YOT',     category: 'basic',    order: 4  },
  'slip':               { name: '미끄러뜨리기',       nameEn: 'Slip Knitwise',         abbr: 'Sl k',    category: 'basic',    order: 5  },
  'slipwyif':           { name: '실앞미끄러뜨리기',   nameEn: 'Slip Wyif',             abbr: 'Sl wyif', category: 'basic',    order: 6  },
  'slantleft':          { name: '왼경사',             nameEn: 'Slant Left',            abbr: 'SL',      category: 'basic',    order: 7  },
  'slantright':         { name: '오른경사',           nameEn: 'Slant Right',           abbr: 'SR',      category: 'basic',    order: 8  },
  'nostitch':           { name: '없는칸',             nameEn: 'No Stitch',             abbr: 'NS',      category: 'basic',    order: 9  },
  'bindoff':            { name: '코막음',             nameEn: 'Bind Off',              abbr: 'BO',      category: 'basic',    order: 10 },

  // decrease
  'decreaseleft':       { name: '왼모아겉뜨기',       nameEn: 'SSK',                   abbr: 'SSK',     category: 'decrease', order: 11 },
  'decreaseright':      { name: '오른모아겉뜨기',     nameEn: 'K2tog',                 abbr: 'K2tog',   category: 'decrease', order: 12 },
  'decreaseleft.2w':    { name: '2코왼모아겉뜨기',    nameEn: 'SSK (2w)',              abbr: 'SSK2w',   category: 'decrease', order: 13, spanWidth: 2 },
  'decreaseright.2w':   { name: '2코오른모아겉뜨기',  nameEn: 'K2tog (2w)',            abbr: 'K2tog2w', category: 'decrease', order: 14, spanWidth: 2 },
  'decreaseleft_purl':  { name: '왼모아안뜨기',       nameEn: 'SSP',                   abbr: 'SSP',     category: 'decrease', order: 15 },
  'decreaseright_purl': { name: '오른모아안뜨기',     nameEn: 'P2tog',                 abbr: 'P2tog',   category: 'decrease', order: 16 },
  'decrease3to1centered':{ name: '3코중앙모아뜨기',   nameEn: 'CDD',                   abbr: 'CDD',     category: 'decrease', order: 17 },
  'decrease3to1left':   { name: '3코왼모아겉뜨기',    nameEn: 'SSSK',                  abbr: 'SSSK',    category: 'decrease', order: 18 },
  'decrease3to1right':  { name: '3코오른모아겉뜨기',  nameEn: 'K3tog',                 abbr: 'K3tog',   category: 'decrease', order: 19 },
  'decrease4to1left':   { name: '4코왼모아뜨기',      nameEn: '4to1 Left',             abbr: 'D4L',     category: 'decrease', order: 20, spanWidth: 2 },
  'decrease4to1right':  { name: '4코오른모아뜨기',    nameEn: '4to1 Right',            abbr: 'D4R',     category: 'decrease', order: 21, spanWidth: 2 },
  'decrease5to1centered':{ name: '5코중앙모아뜨기',   nameEn: '5to1 Center',           abbr: 'D5C',     category: 'decrease', order: 22, spanWidth: 3 },
  'decrease5to1left':   { name: '5코왼모아뜨기',      nameEn: '5to1 Left',             abbr: 'D5L',     category: 'decrease', order: 23, spanWidth: 3 },
  'decrease5to1right':  { name: '5코오른모아뜨기',    nameEn: '5to1 Right',            abbr: 'D5R',     category: 'decrease', order: 24, spanWidth: 3 },
  'decrease6to1left':   { name: '6코왼모아뜨기',      nameEn: '6to1 Left',             abbr: 'D6L',     category: 'decrease', order: 25, spanWidth: 3 },
  'decrease6to1right':  { name: '6코오른모아뜨기',    nameEn: '6to1 Right',            abbr: 'D6R',     category: 'decrease', order: 26, spanWidth: 3 },
  'decrease7to1':       { name: '7코모아뜨기',        nameEn: '7to1',                  abbr: 'D7',      category: 'decrease', order: 27, spanWidth: 4 },
  'decrease7to1left':   { name: '7코왼모아뜨기',      nameEn: '7to1 Left',             abbr: 'D7L',     category: 'decrease', order: 28, spanWidth: 4 },
  'decrease7to1right':  { name: '7코오른모아뜨기',    nameEn: '7to1 Right',            abbr: 'D7R',     category: 'decrease', order: 29, spanWidth: 4 },
  'passleft':           { name: '왼덮어씌우기',        nameEn: 'Pass Left',             abbr: 'PL',      category: 'decrease', order: 30 },
  'passright':          { name: '오른덮어씌우기',      nameEn: 'Pass Right',            abbr: 'PR',      category: 'decrease', order: 31 },

  // increase
  'increaseleft':       { name: '왼쪽늘리기(M1L)',    nameEn: 'M1L',                   abbr: 'M1L',     category: 'increase', order: 32 },
  'increaseright':      { name: '오른쪽늘리기(M1R)',  nameEn: 'M1R',                   abbr: 'M1R',     category: 'increase', order: 33 },
  'increase1to3':       { name: '1코에서3코늘리기',   nameEn: '1to3',                  abbr: '1to3',    category: 'increase', order: 34 },

  // cable
  'c2over1left':        { name: '2코앞케이블',         nameEn: 'C2/1 Left',             abbr: 'C2/1L',   category: 'cable',    order: 35, spanWidth: 3 },
  'c2over1right':       { name: '2코뒤케이블',         nameEn: 'C2/1 Right',            abbr: 'C2/1R',   category: 'cable',    order: 36, spanWidth: 3 },
  'c2over1left-purl':   { name: '2코앞케이블(안뜨기)', nameEn: 'C2/1 Left Purl',        abbr: 'C2/1LP',  category: 'cable',    order: 37, spanWidth: 3 },
  'c2over1right-purl':  { name: '2코뒤케이블(안뜨기)', nameEn: 'C2/1 Right Purl',       abbr: 'C2/1RP',  category: 'cable',    order: 38, spanWidth: 3 },
  'c2over2left':        { name: '4코앞케이블',         nameEn: 'C2/2 Left',             abbr: 'C2/2L',   category: 'cable',    order: 39, spanWidth: 4 },
  'c2over2right':       { name: '4코뒤케이블',         nameEn: 'C2/2 Right',            abbr: 'C2/2R',   category: 'cable',    order: 40, spanWidth: 4 },
  'c2over2left-purl':   { name: '4코앞케이블(안뜨기)', nameEn: 'C2/2 Left Purl',        abbr: 'C2/2LP',  category: 'cable',    order: 41, spanWidth: 4 },
  'c2over2right-purl':  { name: '4코뒤케이블(안뜨기)', nameEn: 'C2/2 Right Purl',       abbr: 'C2/2RP',  category: 'cable',    order: 42, spanWidth: 4 },
  'crossleft':          { name: '교차(왼)',             nameEn: 'Cross Left',            abbr: 'XL',      category: 'cable',    order: 43, spanWidth: 2 },
  'crossright':         { name: '교차(오)',             nameEn: 'Cross Right',           abbr: 'XR',      category: 'cable',    order: 44, spanWidth: 2 },
  'crossleft_purl':     { name: '교차(왼,안뜨기)',     nameEn: 'Cross Left Purl',       abbr: 'XLP',     category: 'cable',    order: 45, spanWidth: 2 },
  'crossright_purl':    { name: '교차(오,안뜨기)',     nameEn: 'Cross Right Purl',      abbr: 'XRP',     category: 'cable',    order: 46, spanWidth: 2 },
  'twist':              { name: '꼰뜨기',              nameEn: 'Twist',                 abbr: 'Tw',      category: 'cable',    order: 47, spanWidth: 2 },
  'twist.straight':     { name: '꼰뜨기(직선)',        nameEn: 'Twist Straight',        abbr: 'TwS',     category: 'cable',    order: 48, spanWidth: 2 },
  'twist_purl':         { name: '꼰뜨기(안뜨기)',      nameEn: 'Twist Purl',            abbr: 'TwP',     category: 'cable',    order: 49, spanWidth: 2 },
  'twistleft':          { name: '왼꼬기',              nameEn: 'Twist Left',            abbr: 'TwL',     category: 'cable',    order: 50, spanWidth: 2 },
  'twistright':         { name: '오른꼬기',            nameEn: 'Twist Right',           abbr: 'TwR',     category: 'cable',    order: 51, spanWidth: 2 },
  'twistleft_purl':     { name: '왼꼬기(안뜨기)',      nameEn: 'Twist Left Purl',       abbr: 'TwLP',    category: 'cable',    order: 52, spanWidth: 2 },
  'twistright_purl':    { name: '오른꼬기(안뜨기)',    nameEn: 'Twist Right Purl',      abbr: 'TwRP',    category: 'cable',    order: 53, spanWidth: 2 },
  'twistrightsvg':      { name: '오른꼬기2',           nameEn: 'Twist Right 2',         abbr: 'TwR2',    category: 'cable',    order: 54, spanWidth: 2 },

  // special (dip + templates)
  'dip':                { name: '아래코겉뜨기',         nameEn: 'Dip Stitch',            abbr: 'Dip',     category: 'special',  order: 55 },
  'dip_purl':           { name: '아래코안뜨기',         nameEn: 'Dip Purl',              abbr: 'DipP',    category: 'special',  order: 56 },
  'diptwist':           { name: '아래코꼰뜨기',         nameEn: 'Dip Twist',             abbr: 'DipT',    category: 'special',  order: 57 },
  'template':           { name: '템플릿(1코)',          nameEn: 'Template 1x1',          abbr: 'T1',      category: 'special',  order: 58, spanWidth: 1,  spanHeight: 1 },
  'template.2w':        { name: '템플릿(2코)',          nameEn: 'Template 2w',           abbr: 'T2w',     category: 'special',  order: 59, spanWidth: 2,  spanHeight: 1 },
  'template.3w':        { name: '템플릿(3코)',          nameEn: 'Template 3w',           abbr: 'T3w',     category: 'special',  order: 60, spanWidth: 3,  spanHeight: 1 },
  'template.4w':        { name: '템플릿(4코)',          nameEn: 'Template 4w',           abbr: 'T4w',     category: 'special',  order: 61, spanWidth: 4,  spanHeight: 1 },
  'template.2h':        { name: '템플릿(2단)',          nameEn: 'Template 2h',           abbr: 'T2h',     category: 'special',  order: 62, spanWidth: 1,  spanHeight: 2 },
};

// ── HTTP 헬퍼 ─────────────────────────────────────────────────────────────
function httpsGet(hostname, urlPath, headers = {}) {
  return new Promise((resolve, reject) => {
    const req = https.request({ hostname, path: urlPath, method: 'GET', headers }, (res) => {
      let d = ''; res.on('data', (c) => (d += c)); res.on('end', () => resolve({ status: res.statusCode, body: d }));
    });
    req.on('error', reject); req.end();
  });
}

function httpsPost(hostname, urlPath, body, headers = {}) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(body);
    const req = https.request(
      { hostname, path: urlPath, method: 'POST', headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(data), ...headers } },
      (res) => { let d = ''; res.on('data', (c) => (d += c)); res.on('end', () => resolve({ status: res.statusCode, body: d })); }
    );
    req.on('error', reject); req.write(data); req.end();
  });
}

// ── 토큰 갱신 ─────────────────────────────────────────────────────────────
async function getAccessToken() {
  const body = JSON.stringify({
    client_id: '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
    client_secret: 'j9iVZfS8kkCEFUPaAeJV0sAi',
    refresh_token: firebaseConfig.tokens.refresh_token,
    grant_type: 'refresh_token',
  });
  const result = await new Promise((resolve, reject) => {
    const req = https.request(
      { hostname: 'oauth2.googleapis.com', path: '/token', method: 'POST', headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body) } },
      (res) => { let d = ''; res.on('data', (c) => (d += c)); res.on('end', () => resolve(JSON.parse(d))); }
    );
    req.on('error', reject); req.write(body); req.end();
  });
  if (!result.access_token) throw new Error(`Token refresh failed: ${JSON.stringify(result)}`);
  return result.access_token;
}

// ── Storage 파일 목록 조회 ────────────────────────────────────────────────
async function listStorageFiles(token) {
  const encodedPrefix = encodeURIComponent(SVG_PREFIX);
  const res = await httpsGet('firebasestorage.googleapis.com', `/v0/b/${BUCKET}/o?prefix=${encodedPrefix}&maxResults=500`, { Authorization: `Bearer ${token}` });
  const data = JSON.parse(res.body);
  if (!data.items) { console.log('파일 없음:', res.body.slice(0, 200)); return []; }
  return data.items.map((item) => ({
    storageName: item.name,
    fileName: path.basename(item.name, '.svg'),
    downloadUrl: `https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/${encodeURIComponent(item.name)}?alt=media`,
  }));
}

// ── Firestore 문서 생성 (문서 ID 지정) ────────────────────────────────────
async function createDocument(token, docId, fields) {
  const urlPath = `/v1/projects/${PROJECT_ID}/databases/(default)/documents/${COLLECTION}?documentId=${encodeURIComponent(docId)}`;
  const body = { fields };
  return httpsPost('firestore.googleapis.com', urlPath, body, { Authorization: `Bearer ${token}` });
}

// ── Dart/Firestore 필드 값 포맷 ───────────────────────────────────────────
function strField(v) { return { stringValue: String(v) }; }
function intField(v) { return { integerValue: String(v) }; }

// ── 메인 ─────────────────────────────────────────────────────────────────
async function run() {
  console.log('🔑 토큰 갱신 중...');
  const token = await getAccessToken();
  console.log('✅ 토큰 갱신 완료\n');

  console.log(`📦 Firebase Storage /${SVG_PREFIX} 파일 목록 조회 중...`);
  const svgFiles = await listStorageFiles(token);
  console.log(`  → ${svgFiles.length}개 SVG 파일 발견\n`);

  let created = 0;
  let skipped = 0;
  let unknown = 0;

  for (const file of svgFiles) {
    const meta = SYMBOL_META[file.fileName];
    if (!meta) {
      console.log(`  ⚠️  [${file.fileName}] 메타데이터 없음 — 스킵`);
      unknown++;
      continue;
    }

    const fields = {
      name:         strField(meta.name),
      nameEn:       strField(meta.nameEn),
      abbreviation: strField(meta.abbr),
      svgUrl:       strField(file.downloadUrl),
      category:     strField(meta.category),
      order:        intField(meta.order),
      spanWidth:    intField(meta.spanWidth  ?? 1),
      spanHeight:   intField(meta.spanHeight ?? 1),
    };

    const res = await createDocument(token, file.fileName, fields);
    if (res.status === 200 || res.status === 201) {
      console.log(`  ✅ [${file.fileName}] → ${meta.name} (${meta.category}, span:${meta.spanWidth ?? 1}x${meta.spanHeight ?? 1})`);
      created++;
    } else if (res.status === 409) {
      console.log(`  ⏭  [${file.fileName}] 이미 존재 — 스킵`);
      skipped++;
    } else {
      console.error(`  ❌ [${file.fileName}] 실패 status=${res.status}`, res.body.slice(0, 200));
    }
  }

  console.log(`\n완료: 생성 ${created}개, 스킵(이미 존재) ${skipped}개, 메타 없음 ${unknown}개`);
}

run().catch((err) => { console.error('오류:', err); process.exit(1); });
