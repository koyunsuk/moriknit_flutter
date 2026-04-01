# MoriKnit Encyclopedia Data Design

## 1. 데이터 모델 초안

| field | type | note |
| --- | --- | --- |
| `id` | string | 문서 ID |
| `slug` | string | URL 친화 식별자 |
| `term_key` | string | 표준 기술 key |
| `category_key` | string | `stitch`, `tool`, `finish`, `measurement` 등 |
| `symbol_key` | string? | 차트 기호 연결 key |
| `term_ko` | string | 한국어 표제어 |
| `term_en` | string | 영어 표제어 |
| `term_ja` | string | 일본어 표제어 |
| `aliases` | list<string> | 검색용 동의어 |
| `description_ko` | string | 한국어 설명 |
| `description_en` | string | 영어 설명 |
| `description_ja` | string | 일본어 설명 |
| `youtube_url` | string? | 설명용 유튜브 링크 |
| `video_url` | string? | 자체/외부 영상 링크 |
| `reference_links` | list<string> | 참고 링크 |
| `difficulty_key` | string | `beginner`, `intermediate`, `advanced` |
| `status` | string | `draft`, `submitted`, `approved`, `rejected` |
| `created_by` | string | 작성자 uid |
| `approved_by` | string? | 승인자 uid |
| `created_at` | timestamp | 생성일 |
| `updated_at` | timestamp | 수정일 |

## 2. 관리자 일괄업로드 구조

### 입력 형식

- Excel 또는 CSV
- 필수 컬럼
  - `term_key`
  - `category_key`
  - `term_ko`
  - `term_en`
  - `description_ko`

### 업로드 흐름

1. 파일 업로드
2. 미리보기 테이블 생성
3. 컬럼 검증
4. key 중복/누락 검증
5. 관리자 확인 후 일괄 반영
6. 에러 row 리포트 출력

### 검증 규칙

- `term_key` 중복 금지
- `category_key`는 허용 enum만 사용
- URL 필드는 `http/https`만 허용
- description 필드는 최소 길이 검증 가능

## 3. 사용자 제안 구조

### 목표

- 사용자도 백과사전 항목을 제안할 수 있다.
- 관리자는 검수 후 승인/반려할 수 있다.

### 상태 흐름

- `draft`
- `submitted`
- `approved`
- `rejected`

### 컬렉션 분리

- `encyclopedia_entries`
  - 실제 승인된 본 데이터
- `encyclopedia_submissions`
  - 사용자 제안 및 관리자 검수 데이터

## 4. 구현 우선순위

1. schema 고정
2. 관리자 업로드 미리보기
3. 사용자 제안 입력 폼
4. 승인/반려 액션
5. 검색과 상세 연결

## 5. 오늘 기준 결론

- 백과사전은 기능보다 구조가 먼저다.
- 유튜브, 영상, 외부자료가 추가되어도 schema가 버텨야 한다.
- 관리자 일괄업로드와 사용자 제안을 동시에 고려해도 key 체계는 단순해야 한다.
