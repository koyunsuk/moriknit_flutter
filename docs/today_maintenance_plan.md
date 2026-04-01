# Today Maintenance Plan

## 목적

- 기능 확장보다 구조 고정을 우선한다.
- 코드를 `껍데기(UI) / 유지보수용 코드(strings, enum, mapping) / DB 구조`로 분리한다.
- 1인 개발자가 직접 수정하기 쉬운 구조를 만든다.

## 작업 목록

| 번호 | 작업 | 목표 | 산출물 |
| --- | --- | --- | --- |
| 1 | 하드코딩 문구 전수 정리 | 화면 문구, 버튼, 다이얼로그, empty state, 상태 라벨, 카테고리 라벨, 토스트, 헤더 문구를 수집한다. | 하드코딩 문구 목록, 우선순위 표 |
| 2 | 문자열 레이어 완전 분리 | 화면 파일에서 직접 텍스트를 쓰지 않고 `app_strings` 기반으로 이동한다. | localization 키 정리, 교체 대상 목록 |
| 3 | UI 껍데기 공통화 | 헤더, 카드, empty/loading/error, section title, modal/sheet, form field, CTA 패턴을 정리한다. | 공통 UI 규칙, 재사용 컴포넌트 목록 |
| 4 | DB 저장값과 표시문구 분리 | DB에는 key만 저장하고, 화면에서만 localization label을 매핑한다. | DB key 규칙 문서 |
| 5 | feature 폴더 구조 통일 | `data / domain / presentation / presentation/widgets` 기준으로 정리한다. | 폴더 규칙, import 정리 |
| 6 | 뜨개 용어/기호 key 초안 작성 | 언어 혼재를 대비해 표준 key를 정의한다. | `knit`, `purl`, `yo`, `k2tog`, `ssk`, `gauge`, `swatch` 등 |
| 7 | 뜨개백과사전 DB 스키마 초안 | 용어, 설명, 기호, 링크, 상태 흐름을 담는 구조를 잡는다. | 백과사전 schema 문서 |
| 8 | 관리자 일괄업로드 구조 설계 | Excel/CSV 업로드, 미리보기, 검증, 일괄 반영 흐름을 정의한다. | 업로드 프로세스 문서 |
| 9 | 사용자 제안 구조 설계 | 사용자가 항목을 제안하고 관리자가 승인하는 흐름을 정의한다. | `draft / submitted / approved / rejected` 상태 흐름 |

## 핵심 기준

- `isKorean` 같은 불리언 중심 분기보다, 선택된 언어 enum으로 바인딩한다.
- DB에는 표시 문구가 아니라 stable key를 저장한다.
- 헤더와 카드 같은 공통 UI는 한 군데에서 수정할 수 있어야 한다.
- 백과사전, 도안제작, 마켓은 모두 같은 키 체계 위에서 확장 가능해야 한다.

## 뜨개백과사전 방향

- 관리자: Excel/CSV 업로드로 일괄 관리
- 사용자: 항목 추가 제안 가능
- 시스템: 관리자 검수 후 승인 반영
- 목표: 다 같이 만드는 뜨개 백과사전
