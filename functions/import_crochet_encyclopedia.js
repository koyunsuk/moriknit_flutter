/**
 * Firestore crochet encyclopedia bulk import — CSV 파싱 + Firestore REST API 방식
 * Firebase CLI 로그인 토큰 자동 사용
 * Run: node functions/import_crochet_encyclopedia.js
 */

const https = require('https');
const path = require('path');
const os = require('os');
const fs = require('fs');

const PROJECT_ID = 'moriknit-ceea9';
const COLLECTION = 'encyclopedia';
const CSV_PATH = path.join('d:', 'tmp', 'moriknit_crochet_encyclopedia.csv');
const ORDER_OFFSET = 1000; // 뜨개(knitting) 항목과 order 충돌 방지

// Firebase CLI 저장 토큰에서 access_token refresh
const configPath = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
const firebaseConfig = JSON.parse(fs.readFileSync(configPath, 'utf8'));

function httpsPost(hostname, urlPath, body, headers) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(body);
    const req = https.request(
      {
        hostname,
        path: urlPath,
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(data), ...headers },
      },
      (res) => {
        let d = '';
        res.on('data', (c) => (d += c));
        res.on('end', () => resolve({ status: res.statusCode, body: d }));
      }
    );
    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

async function getAccessToken() {
  const result = await httpsPost(
    'oauth2.googleapis.com',
    '/token',
    {
      client_id: '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
      client_secret: 'j9iVZfS8kkCEFUPaAeJV0sAi',
      refresh_token: firebaseConfig.tokens.refresh_token,
      grant_type: 'refresh_token',
    },
    {}
  );
  const parsed = JSON.parse(result.body);
  if (!parsed.access_token) throw new Error(`Token refresh failed: ${result.body}`);
  return parsed.access_token;
}

/**
 * CSV 한 줄을 quoted-field 처리하여 파싱
 */
function parseCsvLine(line) {
  const fields = [];
  let current = '';
  let inQuotes = false;

  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (ch === '"') {
      if (inQuotes && line[i + 1] === '"') {
        // escaped quote
        current += '"';
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (ch === ',' && !inQuotes) {
      fields.push(current);
      current = '';
    } else {
      current += ch;
    }
  }
  fields.push(current);
  return fields;
}

/**
 * CSV 파일 전체 파싱 (헤더 행 스킵)
 * columns: term_key, term_ko, term_en, term_ja, abbreviation, category_key,
 *          description_ko, description_en, description_ja, aliases,
 *          symbol_key, reference_url, video_url, order, status
 */
function parseCsv(filePath) {
  const content = fs.readFileSync(filePath, 'utf8');
  const lines = content.split(/\r?\n/).filter((l) => l.trim() !== '');
  // 헤더 스킵
  const rows = lines.slice(1);

  return rows.map((line) => {
    const f = parseCsvLine(line);
    return {
      term_key:        f[0]  || '',
      term_ko:         f[1]  || '',
      term_en:         f[2]  || '',
      term_ja:         f[3]  || '',
      abbreviation:    f[4]  || '',
      category_key:    f[5]  || '',
      description_ko:  f[6]  || '',
      description_en:  f[7]  || '',
      description_ja:  f[8]  || '',
      aliases:         f[9]  || '',
      symbol_key:      f[10] || '',
      reference_url:   f[11] || '',
      video_url:       f[12] || '',
      order:           parseInt(f[13] || '0', 10),
      status:          f[14] || 'approved',
    };
  });
}

function firestoreStringValue(val) {
  return { stringValue: val };
}

function firestoreIntValue(val) {
  return { integerValue: String(val) };
}

function firestoreArrayValue(items) {
  return {
    arrayValue: {
      values: items.map((s) => ({ stringValue: s })),
    },
  };
}

function toFirestoreDoc(row) {
  // aliases: 공백으로 구분된 문자열을 배열로 변환, 빈 문자열은 빈 배열
  const aliasesArr = row.aliases.trim() ? row.aliases.trim().split(/\s+/) : [];

  return {
    fields: {
      term:          firestoreStringValue(row.term_ko),
      termEn:        firestoreStringValue(row.term_en),
      termJa:        firestoreStringValue(row.term_ja),
      abbreviation:  firestoreStringValue(row.abbreviation),
      category:      firestoreStringValue('abbreviation'), // 뜨개 데이터와 동일한 category 값 사용
      craftType:     firestoreStringValue('crochet'),       // 코바늘 구분 신규 필드
      description:   firestoreStringValue(row.description_ko),
      descriptionEn: firestoreStringValue(row.description_en),
      descriptionJa: firestoreStringValue(row.description_ja),
      aliases:       firestoreArrayValue(aliasesArr),
      symbol:        firestoreStringValue(row.symbol_key),
      referenceUrl:  firestoreStringValue(row.reference_url),
      videoUrl:      firestoreStringValue(row.video_url),
      order:         firestoreIntValue(row.order + ORDER_OFFSET),
      status:        firestoreStringValue(row.status),
      createdAt:     { timestampValue: new Date().toISOString() },
    },
  };
}

async function importEntries() {
  console.log('CSV 파일 파싱 중:', CSV_PATH);
  const rows = parseCsv(CSV_PATH);
  console.log(`파싱 완료. ${rows.length}개 항목 발견.`);

  console.log('Firebase CLI 토큰으로 access_token 갱신 중...');
  const token = await getAccessToken();
  console.log('토큰 갱신 완료. Firestore REST API로 업로드 시작...');

  let count = 0;
  let errors = 0;

  for (const row of rows) {
    const doc = toFirestoreDoc(row);
    const urlPath = `/v1/projects/${PROJECT_ID}/databases/(default)/documents/${COLLECTION}`;
    const body = JSON.stringify(doc);

    const result = await new Promise((resolve, reject) => {
      const req = https.request(
        {
          hostname: 'firestore.googleapis.com',
          path: urlPath,
          method: 'POST',
          headers: {
            Authorization: `Bearer ${token}`,
            'Content-Type': 'application/json',
            'Content-Length': Buffer.byteLength(body),
          },
        },
        (res) => {
          let d = '';
          res.on('data', (c) => (d += c));
          res.on('end', () => resolve({ status: res.statusCode, body: d }));
        }
      );
      req.on('error', reject);
      req.write(body);
      req.end();
    });

    if (result.status === 200) {
      count++;
      console.log(`  [${count}/${rows.length}] ✅ ${row.term_key} (${row.term_ko}) order=${row.order + ORDER_OFFSET}`);
    } else {
      errors++;
      console.error(`  ❌ [${row.term_key}] status=${result.status}`, result.body.slice(0, 300));
    }
  }

  console.log(`\n완료. 성공 ${count}/${rows.length}개, 오류 ${errors}개.`);
  if (errors > 0) process.exit(1);
}

importEntries().catch((err) => {
  console.error('오류:', err);
  process.exit(1);
});
