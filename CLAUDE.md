# MoriKnit Flutter - Claude 설정

## 작업 방식 (최우선 원칙)
- 모든 수정/기능 작업은 서브에이전트 개념으로 진행. 플랫폼(웹/모바일앱/데스크탑) 및 기능 단위로 분리.
- 독립적인 작업(파일 그룹이 겹치지 않는 경우)은 항상 병렬 서브에이전트로 동시 실행.
- 여러 파일을 읽어야 할 때도 병렬로 동시에 읽어줘.
- 에이전트 완료 후 결과를 이 세션에 요약 보고해줘.
- 작업 기획 단계에서 병렬 분리 가능 여부를 먼저 설계 후 진행.

## 응답 스타일
- 응답은 짧고 핵심만. 불필요한 설명 생략.
- 완료된 작업은 표로 간결하게 정리.
- 항상 존댓말(경어체)로 응답. 반말 금지.

## 이슈 관리
- 작업 지시 → 즉시 GitHub 이슈 생성 (repo: koyunsuk/moriknit_flutter)
- 이슈 생성 후 반드시 제목에 번호 포함되도록 title 업데이트:
  1. `gh issue create` → URL에서 번호 추출
  2. `gh issue edit {N} --title "#N [카테고리] 제목"` 으로 업데이트
- 이슈 제목 형식: `{상태이모지} {플래그이모지} #N [카테고리] 제목`
  - 상태 이모지 (필수, 1개): 🟢 완료/배포됨 | 🟡 진행 중 | 🔵 대기 중 | 🔴 차단/문제
  - 플래그 이모지 (선택, 복수 가능): 🚨 긴급 | 🚩 중요 | 👤 사용자보고 | ⭐ 프리미엄 우선처리
  - 예: `🟡 🚨 #6 [기능] 마이페이지 버그리포트`
  - 이슈 생성 시 기본 상태는 🔵 대기 중으로 시작
- 이슈 본문은 `- [ ]` 체크박스 형식으로 서브항목 작성 (진행률 자동 표시)
- 각 항목에 수정 파일 및 변경 내용 명시: `→ 파일경로: 변경내용`
- 체크박스는 항상 `- [ ]` 미체크로만 생성. Claude가 임의로 `- [x]` 체크 금지
- 사용자가 직접 확인 후 체크하는 방식
- 이슈는 Claude가 임의로 닫지 않음. 사용자 승인 후에만 close.
- **기존 이슈에 대한 피드백/추가 작업은 새 이슈 생성 금지.** 기존 이슈에 항목 추가할지 먼저 물어볼 것.
- 작업 완료 후 사용자에게 "이슈 #N 점검해 주세요" 요청.
- 세션 시작 시 "이슈 확인해" 요청이 오면 열린 이슈 목록 먼저 확인.

## 이슈 라벨 구분 (A안)
- **개발팀 이슈** (Claude 생성): `gh issue create --label "dev-issue"` 필수
  → 작업 지시, 기능 개선, 버그 발견 등 개발팀 주도 이슈
- **사용자 접수 버그**: 앱 내 버그신고 시트 → Firestore + GitHub label `user-report` 자동 부여
  → bug_report_repository.dart 에서 자동 처리
- 이슈 생성 시 항상 `--label "dev-issue"` 추가할 것

## 작업 상황 보고
- 장기 작업(3단계 이상) 진행 중 각 단계 완료 시 Pushover로 진행 상황 알림 전송.
- 알림 형식: "🔄 {단계명} 완료 ({N}/{총N})" — Node.js pushover_notify.sh 사용.
- 세션 내 주요 완료 시점(빌드 완료, 배포 완료, 구현 완료 등)마다 보고.

## CLAUDE.md 동기화
- 프로젝트 CLAUDE.md에 내용 추가 시 전역 CLAUDE.md에도 동일하게 반영.

## 코드 품질
- 모든 코드는 재사용 및 유지보수가 용이하도록 최대한 모듈화.
- UI는 Shell 개념을 높은 중요도로 인지 (공통 Shell → 개별 화면 구성).
- UI / DB / Code 개념 분리 원칙 매우 중요.

## UI 원칙
- 저장 관련 UI 통일: "저장하는 중입니다." 작은 팝업 + 프로그레스 표시.
- 중복 버튼(저장, 새로만들기 등) 발견 시 삭제.
- 헤더는 공통 컴포넌트로 관리 (스와치/프로젝트/도안 등 통일성 유지).
- 기준 화면: 스와치 화면 → 모든 저장 화면의 UI 레퍼런스.

## 고정 UI 패턴 — 입력화면 표준 (기준: swatch_input_screen.dart)

### 입력/편집 화면 구조
- **AppBar**: `arrow_back_ios (size 20, color C.tx)` + 제목 `T.h3` + (선택) AppBar actions에 저장 버튼
- **Scaffold body**: `Stack([BgOrbs(), SingleChildScrollView(...)])`, padding `fromLTRB(16, 12, 16, 28)`
- **섹션 레이블**: `SectionTitle` 공통 위젯 고정 사용 — `_SectionLabel` 같은 파일별 커스텀 위젯 금지
- **TextField**: `labelText` + `hintText` 병용, border는 테마 기본값 (`OutlineInputBorder` 직접 지정 금지)
  - `fillColor`: 항상 `C.gx` (흰색 또는 다른 색상 금지)
- **저장 버튼**: `bottomNavigationBar` 안에 `SafeArea > ElevatedButton (height 54, width double.infinity)`
  - AppBar에 저장 버튼이 있는 경우 body 하단 버튼은 제거 (중복 금지)

### 선택/토글 UI 표준 (칩 스타일)
- **선택 위젯**: `MoriChip` 또는 아래 커스텀 칩 패턴 사용. `SegmentedButton`, `RadioListTile`, `Switch` 금지.
- **칩 스타일** (선택/미선택):
  ```dart
  // 선택됨
  color: C.lv, border: C.lv, text: Colors.white, fontWeight: w700
  // 미선택
  color: C.lvL, border: C.lv.withValues(alpha: 0.20), text: C.lvD, fontWeight: w500
  borderRadius: BorderRadius.circular(20), padding: horizontal 10 vertical 6
  ```
- **기준 파일**: `project_input_screen.dart`의 `_StatusSelector`

### 사진 첨부 표준 (갤러리 + 즉시촬영 항상 함께)
- **모든 사진 첨부 기능**: 갤러리 선택 + 즉시촬영 두 가지 옵션을 항상 함께 제공
- 구현 방식: `_showImageSourceDialog()` 공통 패턴 사용 — 카메라/갤러리 선택 bottomSheet 후 `ImagePicker` 호출
- 단일 버튼(갤러리만 또는 카메라만) 금지. 사용자가 항상 선택 가능해야 함.
- **기준 파일**: `project_input_screen.dart`의 `_showImageSourceDialog()` + `_pickCover()` 패턴

### 수정/삭제 액션 표준 (점세개 팝업)
- **모든 상세 화면 AppBar**: 수정/삭제 아이콘을 개별 `IconButton`으로 두지 말고 `PopupMenuButton<String>(icon: Icons.more_vert)` 하나로 통합
- 메뉴 항목: `수정` (기본색), `삭제` (color: C.og)
- **기준 파일**: `counter_screen.dart`의 AppBar actions
