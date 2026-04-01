# Hardcoded Strings Audit

## 목적

- 화면 파일에 직접 들어간 문자열을 찾아 localization 레이어로 이동한다.
- 깨진 한글, 중복 문구, 언어 혼합 표기를 줄인다.

## Priority 1

- 로그인 / 회원가입
- 홈
- 프로젝트
- 내 도안
- 스와치
- 마이페이지
- 메신저
- 마켓
- 커뮤니티

## Priority 2

- 관리자
- 뜨개백과사전
- 도안제작
- 게이지 계산기
- 카운터
- 도구 화면

## Priority 3

- 랜딩 페이지
- 상세용 다이얼로그
- 토스트 / snackbar
- 파일 업로드 보조 문구

## 점검 항목

- 제목/부제목
- 버튼 문구
- empty state
- 에러 메시지
- 카테고리 라벨
- 상태값 라벨
- placeholder / hint text
- 파일/이미지 업로드 안내

## 정리 원칙

- UI 문구는 `app_strings`로 이동
- DB에는 key만 저장
- 언어 분기는 `AppLanguage` enum 기준으로 처리
- `isKorean` 하드코딩 분기는 제거 대상
