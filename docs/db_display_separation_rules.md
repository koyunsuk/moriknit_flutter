# DB / Display Separation Rules

## 원칙

1. DB에는 표시용 문자열을 저장하지 않는다.
2. DB에는 항상 stable key를 저장한다.
3. 화면에서는 key를 localization 문자열로 변환해서 보여준다.
4. 관리자 업로드 템플릿도 같은 key 체계를 사용한다.

## 저장 예시

### 좋은 예

- `category_key: pattern_share`
- `difficulty_key: beginner`
- `status: approved`
- `term_key: knit`

### 나쁜 예

- `category: 도안공유`
- `difficulty: 초급`
- `status: 승인완료`
- `term: 겉뜨기`

## 적용 대상

- 커뮤니티 카테고리
- 마켓 상품 타입
- 도안 타입
- 뜨개백과사전 분류
- 난이도
- 상태값
- 정렬/필터 옵션

## 화면 표시 방식

- 한국어: `pattern_share -> 도안공유`
- 영어: `pattern_share -> Pattern Share`
- 일본어: `pattern_share -> パターン共有`

## 장점

- 다국어 확장이 쉬움
- 운영 중 문구 변경이 쉬움
- 과거 데이터와 신규 데이터가 같은 규칙을 가짐
- 검색, 필터, 업로드 검증이 쉬움
