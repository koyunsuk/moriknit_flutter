// 일회용 스크립트 — koyunsuk@gmail.com 의 핸들을 @moriknit → @koyunsuk 으로 변경.
// 30일 변경 제한은 UI에서만 검사하므로 Admin SDK 로는 즉시 변경 가능.
//
// 실행: node functions/scripts/change_handle.js
//
// 사전 점검:
//   - handles/koyunsuk 도큐먼트가 비어있는지 (다른 사용자 점유 시 중단)
//   - handles/moriknit 도큐먼트 userId 가 본인 uid 인지 (안전 확인)

const admin = require('firebase-admin');

const TARGET_EMAIL = 'koyunsuk@gmail.com';
const NEW_HANDLE = 'koyunsuk';
const OLD_HANDLE = 'moriknit';

admin.initializeApp({ projectId: 'moriknit-ceea9' });

const auth = admin.auth();
const db = admin.firestore();

async function main() {
  // 1. uid 조회
  const userRecord = await auth.getUserByEmail(TARGET_EMAIL);
  const uid = userRecord.uid;
  console.log(`✅ 본인 uid: ${uid}`);

  // 2. 사전 점검 — 새 핸들 (koyunsuk) 점유 여부
  const newRef = db.collection('handles').doc(NEW_HANDLE);
  const oldRef = db.collection('handles').doc(OLD_HANDLE);
  const userRef = db.collection('users').doc(uid);

  const [newSnap, oldSnap, userSnap] = await Promise.all([
    newRef.get(),
    oldRef.get(),
    userRef.get(),
  ]);

  if (newSnap.exists) {
    const owner = newSnap.data()?.userId;
    if (owner !== uid) {
      console.error(`❌ handles/${NEW_HANDLE} 이미 다른 사용자(${owner})가 점유 중. 중단.`);
      process.exit(1);
    } else {
      console.log(`⚠️ handles/${NEW_HANDLE} 이미 본인 소유. 안전.`);
    }
  } else {
    console.log(`✅ handles/${NEW_HANDLE} 비어있음. 변경 가능.`);
  }

  if (oldSnap.exists) {
    const owner = oldSnap.data()?.userId;
    if (owner !== uid) {
      console.error(`⚠️ handles/${OLD_HANDLE} 이 본인 소유 아님(${owner}). 그래도 본인 users.handle 만 변경 진행.`);
    } else {
      console.log(`✅ handles/${OLD_HANDLE} 본인 소유 확인. 트랜잭션에서 삭제.`);
    }
  } else {
    console.log(`ℹ️ handles/${OLD_HANDLE} 도큐먼트 없음 (이미 해제됨).`);
  }

  console.log(`📋 현재 users/${uid}.handle:`, userSnap.data()?.handle);

  // 3. 트랜잭션 실행
  await db.runTransaction(async (tx) => {
    // 재확인 (트랜잭션 안에서 race condition 방지)
    const newSnapTx = await tx.get(newRef);
    if (newSnapTx.exists && newSnapTx.data()?.userId !== uid) {
      throw new Error(`handles/${NEW_HANDLE} 점유 충돌`);
    }
    // 새 핸들 등록
    tx.set(newRef, {
      userId: uid,
      displayHandle: NEW_HANDLE,
      reservedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    // 기존 핸들 해제 (본인 소유일 때만)
    const oldSnapTx = await tx.get(oldRef);
    if (oldSnapTx.exists && oldSnapTx.data()?.userId === uid) {
      tx.delete(oldRef);
    }
    // users 문서 update
    tx.set(userRef, {
      handle: NEW_HANDLE,
      handleUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  });

  console.log(`🎉 변경 완료. ${TARGET_EMAIL} → @${NEW_HANDLE}`);

  // 4. 사후 검증
  const verifyUserSnap = await userRef.get();
  console.log(`✅ users/${uid}.handle:`, verifyUserSnap.data()?.handle);
  process.exit(0);
}

main().catch((e) => {
  console.error('❌ 실패:', e);
  process.exit(1);
});
