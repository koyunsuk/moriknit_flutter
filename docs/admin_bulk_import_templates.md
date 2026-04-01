# Admin Bulk Import Templates

## 목적

- 관리자 화면에서 상품, 도안, 뜨개백과사전, 커뮤니티 글, 실 목록, 바늘 목록을 일괄 등록한다.
- DB에는 표시 문구가 아니라 `stable key`와 구조화된 필드를 저장한다.
- 필수 항목은 템플릿에서 별도로 안내한다.

## 공통 규칙

- 첫 줄은 헤더다.
- 둘째 줄은 `required / optional` 안내 행이다.
- CSV, TSV, XLSX 업로드를 지원한다.
- 브랜드 수정이 필요하면 `brand_id`를 채운다.
- `brand_id`가 비어 있으면 새 문서로 생성된다.

## 1. 상품 템플릿

- 파일: `market_items_template.csv`
- 주요 컬럼
  - `title`
  - `description`
  - `category_key`
  - `price`
  - `image_url`
  - `pdf_url`
  - `seller_name`

## 2. 도안 템플릿

- 파일: `pattern_items_template.csv`
- 주요 컬럼
  - `title`
  - `description`
  - `price`
  - `pdf_url`
  - `seller_name`

## 3. 뜨개백과사전 템플릿

- 파일: `encyclopedia_template.csv`
- 주요 컬럼
  - `term_key`
  - `category_key`
  - `term_ko`
  - `term_en`
  - `term_ja`
  - `description_ko`
  - `reference_url`
  - `video_url`

## 4. 커뮤니티 글 템플릿

- 파일: `community_posts_template.csv`
- 주요 컬럼
  - `title`
  - `content`
  - `category_key`
  - `author_name`
  - `image_urls`
  - `attachment_urls`

## 5. 실 목록 템플릿

- 파일: `yarn_brands_template.csv`
- 주요 컬럼
  - `brand_id`
  - `name`
  - `country`
  - `website`
  - `notes`
  - `is_active`
  - `sort_order`

## 6. 바늘 목록 템플릿

- 파일: `needle_brands_template.csv`
- 주요 컬럼
  - `brand_id`
  - `name`
  - `country`
  - `website`
  - `notes`
  - `is_active`
  - `sort_order`

## 검증 체크

- 필수값 누락 여부
- key 컬럼 형식
- URL 형식
- 중복 key/brand_id 여부
- 숫자 컬럼 변환 가능 여부
