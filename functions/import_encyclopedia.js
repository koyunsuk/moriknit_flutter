/**
 * Firestore encyclopedia bulk import — Firestore REST API 방식 (service-account 불필요)
 * Firebase CLI 로그인 토큰 자동 사용
 * Run: node functions/import_encyclopedia.js
 */

const https = require('https');
const path = require('path');
const os = require('os');
const fs = require('fs');

const PROJECT_ID = 'moriknit-ceea9';
const COLLECTION = 'encyclopedia';

// Firebase CLI 저장 토큰에서 access_token refresh
const configPath = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
const firebaseConfig = JSON.parse(fs.readFileSync(configPath, 'utf8'));

function httpsPost(hostname, path, body, headers) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(body);
    const req = https.request(
      { hostname, path, method: 'POST', headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(data), ...headers } },
      (res) => {
        let d = '';
        res.on('data', (c) => d += c);
        res.on('end', () => resolve({ status: res.statusCode, body: JSON.parse(d) }));
      }
    );
    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

async function getAccessToken() {
  const result = await httpsPost('oauth2.googleapis.com', '/token', {
    client_id: '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
    client_secret: 'j9iVZfS8kkCEFUPaAeJV0sAi',
    refresh_token: firebaseConfig.tokens.refresh_token,
    grant_type: 'refresh_token',
  }, {});
  if (!result.body.access_token) throw new Error(`Token refresh failed: ${JSON.stringify(result.body)}`);
  return result.body.access_token;
}

function firestoreValue(val) {
  if (typeof val === 'string') return { stringValue: val };
  if (typeof val === 'number') return { integerValue: String(val) };
  if (typeof val === 'boolean') return { booleanValue: val };
  return { nullValue: null };
}

function toFirestoreDoc(entry) {
  const fields = {};
  for (const [k, v] of Object.entries(entry)) {
    fields[k] = firestoreValue(v);
  }
  return { fields };
}

const entries = [
  { order: 1,   abbreviation: 'k',      termEn: 'knit',                   term: '겉뜨기',            category: 'abbreviation' },
  { order: 2,   abbreviation: 'p',      termEn: 'purl',                   term: '안뜨기',            category: 'abbreviation' },
  { order: 3,   abbreviation: 'yo',     termEn: 'yarn over',              term: '실 걸기',           category: 'abbreviation' },
  { order: 4,   abbreviation: 'k2tog',  termEn: 'knit two together',      term: '두코 모아 겉뜨기',  category: 'abbreviation' },
  { order: 5,   abbreviation: 'ssk',    termEn: 'slip slip knit',         term: '왼코줄임',          category: 'abbreviation' },
  { order: 6,   abbreviation: 'p2tog',  termEn: 'purl two together',      term: '두코 모아 안뜨기',  category: 'abbreviation' },
  { order: 7,   abbreviation: 'co',     termEn: 'cast on',                term: '코잡기',            category: 'abbreviation' },
  { order: 8,   abbreviation: 'bo',     termEn: 'bind off',               term: '코막음',            category: 'abbreviation' },
  { order: 9,   abbreviation: 'sl',     termEn: 'slip',                   term: '코 미끄러뜨리기',   category: 'abbreviation' },
  { order: 10,  abbreviation: 'st',     termEn: 'stitch',                 term: '코',                category: 'abbreviation' },
  { order: 11,  abbreviation: 'sts',    termEn: 'stitches',               term: '코들',              category: 'abbreviation' },
  { order: 12,  abbreviation: 'rep',    termEn: 'repeat',                 term: '반복',              category: 'abbreviation' },
  { order: 13,  abbreviation: 'rnd',    termEn: 'round',                  term: '단(원형)',          category: 'abbreviation' },
  { order: 14,  abbreviation: 'rs',     termEn: 'right side',             term: '겉면',              category: 'abbreviation' },
  { order: 15,  abbreviation: 'ws',     termEn: 'wrong side',             term: '안면',              category: 'abbreviation' },
  { order: 16,  abbreviation: 'inc',    termEn: 'increase',               term: '코 늘리기',         category: 'abbreviation' },
  { order: 17,  abbreviation: 'dec',    termEn: 'decrease',               term: '코 줄이기',         category: 'abbreviation' },
  { order: 18,  abbreviation: 'pm',     termEn: 'place marker',           term: '마커 놓기',         category: 'abbreviation' },
  { order: 19,  abbreviation: 'sm',     termEn: 'slip marker',            term: '마커 옮기기',       category: 'abbreviation' },
  { order: 20,  abbreviation: 'm1',     termEn: 'make one',               term: '한코 늘리기',       category: 'abbreviation' },
  { order: 21,  abbreviation: 'm1l',    termEn: 'make one left',          term: '왼쪽 늘림',         category: 'abbreviation' },
  { order: 22,  abbreviation: 'm1r',    termEn: 'make one right',         term: '오른쪽 늘림',       category: 'abbreviation' },
  { order: 23,  abbreviation: 'tbl',    termEn: 'through back loop',      term: '뒤고리 뜨기',       category: 'abbreviation' },
  { order: 24,  abbreviation: 'tog',    termEn: 'together',               term: '함께 뜨기',         category: 'abbreviation' },
  { order: 25,  abbreviation: 'kfb',    termEn: 'knit front back',        term: '앞뒤 겉뜨기 늘림',  category: 'abbreviation' },
  { order: 26,  abbreviation: 'skp',    termEn: 'slip knit pass',         term: '왼코 줄임',         category: 'abbreviation' },
  { order: 27,  abbreviation: 'wyif',   termEn: 'with yarn in front',     term: '실 앞',             category: 'abbreviation' },
  { order: 28,  abbreviation: 'wyib',   termEn: 'with yarn in back',      term: '실 뒤',             category: 'abbreviation' },
  { order: 29,  abbreviation: 'cn',     termEn: 'cable needle',           term: '케이블 바늘',       category: 'abbreviation' },
  { order: 30,  abbreviation: 'c4f',    termEn: 'cable 4 front',          term: '4코 케이블 앞교차', category: 'abbreviation' },
  { order: 31,  abbreviation: 'c4b',    termEn: 'cable 4 back',           term: '4코 케이블 뒤교차', category: 'abbreviation' },
  { order: 32,  abbreviation: 'k1',     termEn: 'knit 1 stitch',          term: '1코 겉뜨기',        category: 'abbreviation' },
  { order: 33,  abbreviation: 'p1',     termEn: 'purl 1 stitch',          term: '1코 안뜨기',        category: 'abbreviation' },
  { order: 34,  abbreviation: 'k2',     termEn: 'knit 2 stitches',        term: '2코 겉뜨기',        category: 'abbreviation' },
  { order: 35,  abbreviation: 'p2',     termEn: 'purl 2 stitches',        term: '2코 안뜨기',        category: 'abbreviation' },
  { order: 36,  abbreviation: 'k3',     termEn: 'knit 3 stitches',        term: '3코 겉뜨기',        category: 'abbreviation' },
  { order: 37,  abbreviation: 'p3',     termEn: 'purl 3 stitches',        term: '3코 안뜨기',        category: 'abbreviation' },
  { order: 38,  abbreviation: 'k4',     termEn: 'knit 4 stitches',        term: '4코 겉뜨기',        category: 'abbreviation' },
  { order: 39,  abbreviation: 'p4',     termEn: 'purl 4 stitches',        term: '4코 안뜨기',        category: 'abbreviation' },
  { order: 40,  abbreviation: 'k5',     termEn: 'knit 5 stitches',        term: '5코 겉뜨기',        category: 'abbreviation' },
  { order: 41,  abbreviation: 'p5',     termEn: 'purl 5 stitches',        term: '5코 안뜨기',        category: 'abbreviation' },
  { order: 42,  abbreviation: 'k6',     termEn: 'knit 6 stitches',        term: '6코 겉뜨기',        category: 'abbreviation' },
  { order: 43,  abbreviation: 'p6',     termEn: 'purl 6 stitches',        term: '6코 안뜨기',        category: 'abbreviation' },
  { order: 44,  abbreviation: 'k7',     termEn: 'knit 7 stitches',        term: '7코 겉뜨기',        category: 'abbreviation' },
  { order: 45,  abbreviation: 'p7',     termEn: 'purl 7 stitches',        term: '7코 안뜨기',        category: 'abbreviation' },
  { order: 46,  abbreviation: 'k8',     termEn: 'knit 8 stitches',        term: '8코 겉뜨기',        category: 'abbreviation' },
  { order: 47,  abbreviation: 'p8',     termEn: 'purl 8 stitches',        term: '8코 안뜨기',        category: 'abbreviation' },
  { order: 48,  abbreviation: 'k9',     termEn: 'knit 9 stitches',        term: '9코 겉뜨기',        category: 'abbreviation' },
  { order: 49,  abbreviation: 'p9',     termEn: 'purl 9 stitches',        term: '9코 안뜨기',        category: 'abbreviation' },
  { order: 50,  abbreviation: 'k10',    termEn: 'knit 10 stitches',       term: '10코 겉뜨기',       category: 'abbreviation' },
  { order: 51,  abbreviation: 'p10',    termEn: 'purl 10 stitches',       term: '10코 안뜨기',       category: 'abbreviation' },
  { order: 52,  abbreviation: 'k11',    termEn: 'knit 11 stitches',       term: '11코 겉뜨기',       category: 'abbreviation' },
  { order: 53,  abbreviation: 'p11',    termEn: 'purl 11 stitches',       term: '11코 안뜨기',       category: 'abbreviation' },
  { order: 54,  abbreviation: 'k12',    termEn: 'knit 12 stitches',       term: '12코 겉뜨기',       category: 'abbreviation' },
  { order: 55,  abbreviation: 'p12',    termEn: 'purl 12 stitches',       term: '12코 안뜨기',       category: 'abbreviation' },
  { order: 56,  abbreviation: 'k13',    termEn: 'knit 13 stitches',       term: '13코 겉뜨기',       category: 'abbreviation' },
  { order: 57,  abbreviation: 'p13',    termEn: 'purl 13 stitches',       term: '13코 안뜨기',       category: 'abbreviation' },
  { order: 58,  abbreviation: 'k14',    termEn: 'knit 14 stitches',       term: '14코 겉뜨기',       category: 'abbreviation' },
  { order: 59,  abbreviation: 'p14',    termEn: 'purl 14 stitches',       term: '14코 안뜨기',       category: 'abbreviation' },
  { order: 60,  abbreviation: 'k15',    termEn: 'knit 15 stitches',       term: '15코 겉뜨기',       category: 'abbreviation' },
  { order: 61,  abbreviation: 'p15',    termEn: 'purl 15 stitches',       term: '15코 안뜨기',       category: 'abbreviation' },
  { order: 62,  abbreviation: 'k16',    termEn: 'knit 16 stitches',       term: '16코 겉뜨기',       category: 'abbreviation' },
  { order: 63,  abbreviation: 'p16',    termEn: 'purl 16 stitches',       term: '16코 안뜨기',       category: 'abbreviation' },
  { order: 64,  abbreviation: 'k17',    termEn: 'knit 17 stitches',       term: '17코 겉뜨기',       category: 'abbreviation' },
  { order: 65,  abbreviation: 'p17',    termEn: 'purl 17 stitches',       term: '17코 안뜨기',       category: 'abbreviation' },
  { order: 66,  abbreviation: 'k18',    termEn: 'knit 18 stitches',       term: '18코 겉뜨기',       category: 'abbreviation' },
  { order: 67,  abbreviation: 'p18',    termEn: 'purl 18 stitches',       term: '18코 안뜨기',       category: 'abbreviation' },
  { order: 68,  abbreviation: 'k19',    termEn: 'knit 19 stitches',       term: '19코 겉뜨기',       category: 'abbreviation' },
  { order: 69,  abbreviation: 'p19',    termEn: 'purl 19 stitches',       term: '19코 안뜨기',       category: 'abbreviation' },
  { order: 70,  abbreviation: 'k20',    termEn: 'knit 20 stitches',       term: '20코 겉뜨기',       category: 'abbreviation' },
  { order: 71,  abbreviation: 'p20',    termEn: 'purl 20 stitches',       term: '20코 안뜨기',       category: 'abbreviation' },
  { order: 72,  abbreviation: 'k21',    termEn: 'knit 21 stitches',       term: '21코 겉뜨기',       category: 'abbreviation' },
  { order: 73,  abbreviation: 'p21',    termEn: 'purl 21 stitches',       term: '21코 안뜨기',       category: 'abbreviation' },
  { order: 74,  abbreviation: 'k22',    termEn: 'knit 22 stitches',       term: '22코 겉뜨기',       category: 'abbreviation' },
  { order: 75,  abbreviation: 'p22',    termEn: 'purl 22 stitches',       term: '22코 안뜨기',       category: 'abbreviation' },
  { order: 76,  abbreviation: 'k23',    termEn: 'knit 23 stitches',       term: '23코 겉뜨기',       category: 'abbreviation' },
  { order: 77,  abbreviation: 'p23',    termEn: 'purl 23 stitches',       term: '23코 안뜨기',       category: 'abbreviation' },
  { order: 78,  abbreviation: 'k24',    termEn: 'knit 24 stitches',       term: '24코 겉뜨기',       category: 'abbreviation' },
  { order: 79,  abbreviation: 'p24',    termEn: 'purl 24 stitches',       term: '24코 안뜨기',       category: 'abbreviation' },
  { order: 80,  abbreviation: 'k25',    termEn: 'knit 25 stitches',       term: '25코 겉뜨기',       category: 'abbreviation' },
  { order: 81,  abbreviation: 'p25',    termEn: 'purl 25 stitches',       term: '25코 안뜨기',       category: 'abbreviation' },
  { order: 82,  abbreviation: 'k26',    termEn: 'knit 26 stitches',       term: '26코 겉뜨기',       category: 'abbreviation' },
  { order: 83,  abbreviation: 'p26',    termEn: 'purl 26 stitches',       term: '26코 안뜨기',       category: 'abbreviation' },
  { order: 84,  abbreviation: 'k27',    termEn: 'knit 27 stitches',       term: '27코 겉뜨기',       category: 'abbreviation' },
  { order: 85,  abbreviation: 'p27',    termEn: 'purl 27 stitches',       term: '27코 안뜨기',       category: 'abbreviation' },
  { order: 86,  abbreviation: 'k28',    termEn: 'knit 28 stitches',       term: '28코 겉뜨기',       category: 'abbreviation' },
  { order: 87,  abbreviation: 'p28',    termEn: 'purl 28 stitches',       term: '28코 안뜨기',       category: 'abbreviation' },
  { order: 88,  abbreviation: 'k29',    termEn: 'knit 29 stitches',       term: '29코 겉뜨기',       category: 'abbreviation' },
  { order: 89,  abbreviation: 'p29',    termEn: 'purl 29 stitches',       term: '29코 안뜨기',       category: 'abbreviation' },
  { order: 90,  abbreviation: 'k30',    termEn: 'knit 30 stitches',       term: '30코 겉뜨기',       category: 'abbreviation' },
  { order: 91,  abbreviation: 'p30',    termEn: 'purl 30 stitches',       term: '30코 안뜨기',       category: 'abbreviation' },
  { order: 92,  abbreviation: 'k31',    termEn: 'knit 31 stitches',       term: '31코 겉뜨기',       category: 'abbreviation' },
  { order: 93,  abbreviation: 'p31',    termEn: 'purl 31 stitches',       term: '31코 안뜨기',       category: 'abbreviation' },
  { order: 94,  abbreviation: 'k32',    termEn: 'knit 32 stitches',       term: '32코 겉뜨기',       category: 'abbreviation' },
  { order: 95,  abbreviation: 'p32',    termEn: 'purl 32 stitches',       term: '32코 안뜨기',       category: 'abbreviation' },
  { order: 96,  abbreviation: 'k33',    termEn: 'knit 33 stitches',       term: '33코 겉뜨기',       category: 'abbreviation' },
  { order: 97,  abbreviation: 'p33',    termEn: 'purl 33 stitches',       term: '33코 안뜨기',       category: 'abbreviation' },
  { order: 98,  abbreviation: 'k34',    termEn: 'knit 34 stitches',       term: '34코 겉뜨기',       category: 'abbreviation' },
  { order: 99,  abbreviation: 'p34',    termEn: 'purl 34 stitches',       term: '34코 안뜨기',       category: 'abbreviation' },
  { order: 100, abbreviation: 'k35',    termEn: 'knit 35 stitches',       term: '35코 겉뜨기',       category: 'abbreviation' },
  { order: 101, abbreviation: 'p35',    termEn: 'purl 35 stitches',       term: '35코 안뜨기',       category: 'abbreviation' },
  { order: 102, abbreviation: 'k36',    termEn: 'knit 36 stitches',       term: '36코 겉뜨기',       category: 'abbreviation' },
  { order: 103, abbreviation: 'p36',    termEn: 'purl 36 stitches',       term: '36코 안뜨기',       category: 'abbreviation' },
  { order: 104, abbreviation: 'k37',    termEn: 'knit 37 stitches',       term: '37코 겉뜨기',       category: 'abbreviation' },
  { order: 105, abbreviation: 'p37',    termEn: 'purl 37 stitches',       term: '37코 안뜨기',       category: 'abbreviation' },
  { order: 106, abbreviation: 'k38',    termEn: 'knit 38 stitches',       term: '38코 겉뜨기',       category: 'abbreviation' },
  { order: 107, abbreviation: 'p38',    termEn: 'purl 38 stitches',       term: '38코 안뜨기',       category: 'abbreviation' },
  { order: 108, abbreviation: 'k39',    termEn: 'knit 39 stitches',       term: '39코 겉뜨기',       category: 'abbreviation' },
  { order: 109, abbreviation: 'p39',    termEn: 'purl 39 stitches',       term: '39코 안뜨기',       category: 'abbreviation' },
  { order: 110, abbreviation: 'k40',    termEn: 'knit 40 stitches',       term: '40코 겉뜨기',       category: 'abbreviation' },
  { order: 111, abbreviation: 'p40',    termEn: 'purl 40 stitches',       term: '40코 안뜨기',       category: 'abbreviation' },
  { order: 112, abbreviation: 'k2tog',  termEn: 'knit 2 together',        term: '2코 모아 겉뜨기',   category: 'decrease' },
  { order: 113, abbreviation: 'p2tog',  termEn: 'purl 2 together',        term: '2코 모아 안뜨기',   category: 'decrease' },
  { order: 114, abbreviation: 'k3tog',  termEn: 'knit 3 together',        term: '3코 모아 겉뜨기',   category: 'decrease' },
  { order: 115, abbreviation: 'p3tog',  termEn: 'purl 3 together',        term: '3코 모아 안뜨기',   category: 'decrease' },
  { order: 116, abbreviation: 'k4tog',  termEn: 'knit 4 together',        term: '4코 모아 겉뜨기',   category: 'decrease' },
  { order: 117, abbreviation: 'p4tog',  termEn: 'purl 4 together',        term: '4코 모아 안뜨기',   category: 'decrease' },
  { order: 118, abbreviation: 'k5tog',  termEn: 'knit 5 together',        term: '5코 모아 겉뜨기',   category: 'decrease' },
  { order: 119, abbreviation: 'p5tog',  termEn: 'purl 5 together',        term: '5코 모아 안뜨기',   category: 'decrease' },
  { order: 120, abbreviation: 'k6tog',  termEn: 'knit 6 together',        term: '6코 모아 겉뜨기',   category: 'decrease' },
  { order: 121, abbreviation: 'p6tog',  termEn: 'purl 6 together',        term: '6코 모아 안뜨기',   category: 'decrease' },
  { order: 122, abbreviation: 'k7tog',  termEn: 'knit 7 together',        term: '7코 모아 겉뜨기',   category: 'decrease' },
  { order: 123, abbreviation: 'p7tog',  termEn: 'purl 7 together',        term: '7코 모아 안뜨기',   category: 'decrease' },
  { order: 124, abbreviation: 'k8tog',  termEn: 'knit 8 together',        term: '8코 모아 겉뜨기',   category: 'decrease' },
  { order: 125, abbreviation: 'p8tog',  termEn: 'purl 8 together',        term: '8코 모아 안뜨기',   category: 'decrease' },
  { order: 126, abbreviation: 'k9tog',  termEn: 'knit 9 together',        term: '9코 모아 겉뜨기',   category: 'decrease' },
  { order: 127, abbreviation: 'p9tog',  termEn: 'purl 9 together',        term: '9코 모아 안뜨기',   category: 'decrease' },
  { order: 128, abbreviation: 'k10tog', termEn: 'knit 10 together',       term: '10코 모아 겉뜨기',  category: 'decrease' },
  { order: 129, abbreviation: 'p10tog', termEn: 'purl 10 together',       term: '10코 모아 안뜨기',  category: 'decrease' },
  { order: 130, abbreviation: 'k11tog', termEn: 'knit 11 together',       term: '11코 모아 겉뜨기',  category: 'decrease' },
  { order: 131, abbreviation: 'p11tog', termEn: 'purl 11 together',       term: '11코 모아 안뜨기',  category: 'decrease' },
  { order: 132, abbreviation: 'k12tog', termEn: 'knit 12 together',       term: '12코 모아 겉뜨기',  category: 'decrease' },
  { order: 133, abbreviation: 'p12tog', termEn: 'purl 12 together',       term: '12코 모아 안뜨기',  category: 'decrease' },
  { order: 134, abbreviation: 'k13tog', termEn: 'knit 13 together',       term: '13코 모아 겉뜨기',  category: 'decrease' },
  { order: 135, abbreviation: 'p13tog', termEn: 'purl 13 together',       term: '13코 모아 안뜨기',  category: 'decrease' },
  { order: 136, abbreviation: 'k14tog', termEn: 'knit 14 together',       term: '14코 모아 겉뜨기',  category: 'decrease' },
  { order: 137, abbreviation: 'p14tog', termEn: 'purl 14 together',       term: '14코 모아 안뜨기',  category: 'decrease' },
  { order: 138, abbreviation: 'k15tog', termEn: 'knit 15 together',       term: '15코 모아 겉뜨기',  category: 'decrease' },
  { order: 139, abbreviation: 'p15tog', termEn: 'purl 15 together',       term: '15코 모아 안뜨기',  category: 'decrease' },
  { order: 140, abbreviation: 'k16tog', termEn: 'knit 16 together',       term: '16코 모아 겉뜨기',  category: 'decrease' },
  { order: 141, abbreviation: 'p16tog', termEn: 'purl 16 together',       term: '16코 모아 안뜨기',  category: 'decrease' },
  { order: 142, abbreviation: 'k17tog', termEn: 'knit 17 together',       term: '17코 모아 겉뜨기',  category: 'decrease' },
  { order: 143, abbreviation: 'p17tog', termEn: 'purl 17 together',       term: '17코 모아 안뜨기',  category: 'decrease' },
  { order: 144, abbreviation: 'k18tog', termEn: 'knit 18 together',       term: '18코 모아 겉뜨기',  category: 'decrease' },
  { order: 145, abbreviation: 'p18tog', termEn: 'purl 18 together',       term: '18코 모아 안뜨기',  category: 'decrease' },
  { order: 146, abbreviation: 'k19tog', termEn: 'knit 19 together',       term: '19코 모아 겉뜨기',  category: 'decrease' },
  { order: 147, abbreviation: 'p19tog', termEn: 'purl 19 together',       term: '19코 모아 안뜨기',  category: 'decrease' },
  { order: 148, abbreviation: 'k20tog', termEn: 'knit 20 together',       term: '20코 모아 겉뜨기',  category: 'decrease' },
  { order: 149, abbreviation: 'p20tog', termEn: 'purl 20 together',       term: '20코 모아 안뜨기',  category: 'decrease' },
  { order: 150, abbreviation: 'c2f',    termEn: 'cable 2 front',          term: '2코 케이블 앞교차', category: 'cable' },
  { order: 151, abbreviation: 'c2b',    termEn: 'cable 2 back',           term: '2코 케이블 뒤교차', category: 'cable' },
  { order: 152, abbreviation: 'c3f',    termEn: 'cable 3 front',          term: '3코 케이블 앞교차', category: 'cable' },
  { order: 153, abbreviation: 'c3b',    termEn: 'cable 3 back',           term: '3코 케이블 뒤교차', category: 'cable' },
  { order: 154, abbreviation: 'c4f',    termEn: 'cable 4 front',          term: '4코 케이블 앞교차', category: 'cable' },
  { order: 155, abbreviation: 'c4b',    termEn: 'cable 4 back',           term: '4코 케이블 뒤교차', category: 'cable' },
  { order: 156, abbreviation: 'c5f',    termEn: 'cable 5 front',          term: '5코 케이블 앞교차', category: 'cable' },
  { order: 157, abbreviation: 'c5b',    termEn: 'cable 5 back',           term: '5코 케이블 뒤교차', category: 'cable' },
  { order: 158, abbreviation: 'c6f',    termEn: 'cable 6 front',          term: '6코 케이블 앞교차', category: 'cable' },
  { order: 159, abbreviation: 'c6b',    termEn: 'cable 6 back',           term: '6코 케이블 뒤교차', category: 'cable' },
  { order: 160, abbreviation: 'c7f',    termEn: 'cable 7 front',          term: '7코 케이블 앞교차', category: 'cable' },
  { order: 161, abbreviation: 'c7b',    termEn: 'cable 7 back',           term: '7코 케이블 뒤교차', category: 'cable' },
  { order: 162, abbreviation: 'c8f',    termEn: 'cable 8 front',          term: '8코 케이블 앞교차', category: 'cable' },
  { order: 163, abbreviation: 'c8b',    termEn: 'cable 8 back',           term: '8코 케이블 뒤교차', category: 'cable' },
  { order: 164, abbreviation: 'c9f',    termEn: 'cable 9 front',          term: '9코 케이블 앞교차', category: 'cable' },
  { order: 165, abbreviation: 'c9b',    termEn: 'cable 9 back',           term: '9코 케이블 뒤교차', category: 'cable' },
  { order: 166, abbreviation: 'c10f',   termEn: 'cable 10 front',         term: '10코 케이블 앞교차', category: 'cable' },
  { order: 167, abbreviation: 'c10b',   termEn: 'cable 10 back',          term: '10코 케이블 뒤교차', category: 'cable' },
];

async function importEntries() {
  console.log('Firebase CLI 토큰으로 access_token 갱신 중...');
  const token = await getAccessToken();
  console.log('토큰 갱신 완료. Firestore REST API로 업로드 시작...');

  let count = 0;
  for (const e of entries) {
    const doc = toFirestoreDoc({
      abbreviation: e.abbreviation,
      term: e.term,
      termEn: e.termEn,
      description: e.term,
      descriptionEn: e.termEn,
      category: e.category,
      symbol: '',
      order: e.order,
      status: 'approved',
    });

    const result = await new Promise((resolve, reject) => {
      const body = JSON.stringify(doc);
      const urlPath = `/v1/projects/${PROJECT_ID}/databases/(default)/documents/${COLLECTION}`;
      const req = https.request(
        {
          hostname: 'firestore.googleapis.com',
          path: urlPath,
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json',
            'Content-Length': Buffer.byteLength(body),
          },
        },
        (res) => {
          let d = '';
          res.on('data', (c) => d += c);
          res.on('end', () => resolve({ status: res.statusCode, body: d }));
        }
      );
      req.on('error', reject);
      req.write(body);
      req.end();
    });

    if (result.status === 200) {
      count++;
      if (count % 10 === 0) console.log(`  ${count}/${entries.length} 완료`);
    } else {
      console.error(`  ❌ [${e.abbreviation}] status=${result.status}`, result.body.slice(0, 200));
    }
  }

  console.log(`\n✅ 완료. 총 ${count}/${entries.length}개 업로드됨.`);
}

importEntries().catch((err) => {
  console.error('오류:', err);
  process.exit(1);
});
