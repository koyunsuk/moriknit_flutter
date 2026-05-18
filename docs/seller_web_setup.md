# 셀러 웹 사이트 (seller.moriknit.com) 셋업 가이드

이슈 #816 Phase 2 — 모리니트 셀러 전용 웹 사이트.

## 개요

| 항목 | 값 |
|------|-----|
| 도메인 | seller.moriknit.com |
| Firebase Hosting target | `seller` |
| Firebase site ID | `moriknit-seller` |
| Entry | `lib/main_seller.dart` |
| 빌드 출력 | `build/web_seller` |
| 라우터 | `sellerRouterProvider` (모바일셀러 앱과 공유) |

모바일셀러 앱(`lib/main_seller_mobile.dart`)과 코드 100% 공유. 큰 화면(PC)에서 도안 업로드/통계/관리에 편리하도록 웹 빌드만 별도.

---

## 1. Firebase Console에서 호스팅 사이트 신설 (사용자 작업 필요)

배포 전 반드시 Firebase Console에서 `moriknit-seller` 사이트를 생성해야 합니다.

1. https://console.firebase.google.com/project/moriknit-ceea9/hosting/sites 접속
2. **"다른 사이트 추가"** 버튼 클릭
3. site ID 입력: `moriknit-seller`
4. 생성 완료
5. (선택) **도메인 연결**: `seller.moriknit.com`
   - 사이트 카드 → **맞춤 도메인 추가** → `seller.moriknit.com` 입력
   - DNS 레코드(A/TXT) 안내에 따라 도메인 등록기관(가비아 등)에 추가
   - 검증·SSL 발급 대기(수 분~수 시간)

이 단계를 건너뛰면 `firebase deploy --only hosting:seller` 실행 시 "site not found" 에러 발생.

---

## 2. 빌드 및 배포

```bash
bash deploy_web.sh seller
```

전체 사이트(앱+어드민+랜딩+셀러)는:
```bash
bash deploy_web.sh all
```

> 절대 `flutter build web ...` 직접 실행 금지. 항상 `deploy_web.sh` 사용.

---

## 3. 도메인 적용 후 추가 작업

`seller.moriknit.com` 도메인이 활성화되면 카카오 로그인 등 OAuth 콘솔에 도메인을 등록해야 합니다.

- **카카오 디벨로퍼스**: https://developers.kakao.com
  - 내 애플리케이션 → 모리니트 → 플랫폼 → Web → 사이트 도메인에 `https://seller.moriknit.com` 추가
  - 카카오 로그인 → Redirect URI에 `https://seller.moriknit.com/oauth/kakao` 등 필요한 경로 추가
- **Firebase Auth 승인된 도메인**: Firebase Console → Authentication → Settings → 승인된 도메인에 `seller.moriknit.com` 추가

---

## 4. 파일 구조

| 파일 | 역할 |
|------|------|
| `lib/main_seller.dart` | 웹 entry (`usePathUrlStrategy` 호출) |
| `lib/main_seller_mobile.dart` | 모바일 entry (변경 없음) |
| `lib/core/router/seller_router.dart` | 공유 라우터 |
| `firebase.json` | hosting `seller` target 추가 |
| `.firebaserc` | targets `seller`: `["moriknit-seller"]` 추가 |
| `deploy_web.sh` | `seller` 케이스 추가 |
