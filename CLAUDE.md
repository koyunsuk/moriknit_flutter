# MoriKnit Flutter - Claude 설정

## ⛔ 웹 배포 절대 규칙 (세션 시작 시 가장 먼저 읽을 것)

> **웹 관련 작업 전 이 규칙을 반드시 확인하고 진행할 것.**

### 허용되는 유일한 웹 빌드·배포 방법
```bash
bash deploy_web.sh both    # 앱 + 어드민 전체
bash deploy_web.sh app     # 앱만
bash deploy_web.sh admin   # 어드민만
```

### ⛔ 절대 금지 명령어 (이유 불문, 예외 없음)
```bash
# 아래 명령어는 어떤 경우에도 실행 금지
flutter build web                                          # ❌
flutter build web --target lib/main.dart                   # ❌
flutter build web --target lib/main_admin.dart             # ❌
flutter build web --target lib/main_admin.dart --output ... # ❌ (--output 있어도 금지)
firebase deploy --only hosting:app                         # ❌ (스크립트 밖 직접 배포 금지)
firebase deploy --only hosting:admin                       # ❌ (스크립트 밖 직접 배포 금지)
firebase deploy --only hosting                             # ❌ (스크립트 밖 직접 배포 금지)
```

### ⛔ 클린빌드 후 교차배포 절대 금지 (반복 사고 이력)
> `flutter clean` 후 웹 빌드 시 스크립트 없이 직접 실행하면 **앱 빌드가 어드민에, 어드민 빌드가 앱에 배포되는 교차사고** 발생.
> 클린빌드 포함 **모든 상황에서** `bash deploy_web.sh both` 외 방법 절대 금지.
> "이번엔 --output 지정했으니 괜찮다", "클린 후라서 괜찮다" 같은 판단 금지. **스크립트만 사용.**

### 왜 이 규칙이 존재하는가
- Flutter는 `--target` 무관하게 항상 `build/web`에 출력 → `--output` 지정해도 과거 실수 재발 위험
- 스크립트 밖 직접 실행 시 앱·어드민 빌드 교차 배포 발생 이력 있음 (2026-04-03 사고)
- 클린빌드 후에도 동일한 위험 존재 — 클린 여부와 무관하게 규칙 적용
- Claude가 "기술적으로 맞다"고 판단해도 **프로세스 규칙이 우선**

### 웹 코드 수정 완료 후 자동 실행 순서
1. `bash deploy_web.sh both` (또는 변경된 타깃만)
2. Pushover 알림: title="🌐 웹 배포 완료", message="앱+어드민 재배포 완료"

---

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

## APK 설치 완료 후 이슈 체크리스트 보고 (필수)
- APK 설치 완료 시 다음 형식으로 이슈별 체크리스트 보고:
  1. 🟢 완료 이슈 번호별로 — 앱에서 확인할 항목을 `- [ ]` 체크박스로 나열
  2. ⏳ 미구현 항목은 별도 표시
  3. 🔵 대기 중 이슈 목록 표로 정리
  4. ⚪ 장기 검토 이슈 한줄 요약
- 보고 형식 예시:
  ```
  ### 🟢 #N 이슈 제목
  - [ ] 기능 A 동작 확인
  - [ ] 버그 B 수정 확인
  ⏳ 미구현: 항목 X
  ```

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

## APK 빌드·설치 자동 진행 (승인 불필요)
- 모바일(Flutter) 코드 수정 완료 후 사용자 승인 없이 즉시 아래 순서 자동 실행:
  1. `flutter build apk --debug`
  2. `/c/Users/koyunsuk/AppData/Local/Android/Sdk/platform-tools/adb.exe install -r build/app/outputs/flutter-apk/app-debug.apk`
  3. Pushover 알림: title="📱 모리니트 설치 완료", message="모리니트 모바일 신버전 설치했습니다. 확인해주세요"
  4. 해당 이슈 상태 🟢로 업데이트: `gh issue edit {N} --title "🟢 #N [카테고리] 제목"`
- 빌드/설치 완료 후 결과만 보고. 중간에 확인 요청 금지.

## 웹 빌드·배포 → 상단 ⛔ 절대 규칙 섹션 참조

## 이슈 상태 업데이트 (절대 준수)
- **APK 설치 완료 시 무조건 실행**: 해당 작업의 모든 관련 이슈 상태를 🟢로 업데이트
- `gh issue edit {N} --title "🟢 ..."` 명령으로 신호등 이모지 교체
- 여러 이슈인 경우 병렬 실행
- **설치 완료 후 반드시 오픈된 이슈 목록 기준으로 전체 체크리스트 보고 (상세 항목 포함)**
  - 🟢 이번 빌드 포함 이슈: 앱에서 확인할 체크박스 항목 나열
  - 🔵 진행 중/미완료 이슈: 잔여 구현 항목 명시
  - 빌드/설치할 때마다 매번 이 형식으로 보고

## CLAUDE.md 동기화
- 프로젝트 CLAUDE.md에 내용 추가 시 전역 CLAUDE.md에도 동일하게 반영.

## 작업 진행 원칙 (묻지 말고 즉시 진행)
- 모든 기능 구현/버그 수정은 사용자 확인 없이 즉시 진행.
- **단, UI 구성이 변경되는 수정은 반드시 먼저 승인 요청:**
  - 응답 상단에 `⚠️ UI구성이 변경되는 수정입니다` 표시
  - 변경될 UI 구조를 간략히 설명
  - 사용자 승인 후에만 구현 진행
  - 해당 규칙을 CLAUDE.md에 등록 완료됨
- UI 변경 범위: 화면 레이아웃 구조, 네비게이션 흐름, 주요 컴포넌트 추가/제거

## 질문 원칙 (진행 전 확인)
- **질문이 필요한 경우 (진행 전 반드시 질문):**
  - UI에 직접적인 영향이 있는 수정 (레이아웃/흐름/컴포넌트 변경)
  - 수정 방향성이 불명확한 경우 (사용자 의도가 코드만으로 판단 불가한 경우)
- **질문 없이 즉시 진행:**
  - 동작 방식이 코드에서 확인 가능한 경우 → 코드를 먼저 읽고 판단
  - 버그 원인이 명확한 경우
- **질문 방식:** 한 번에 여러 질문 나열 금지. 하나씩 순서대로 질문.

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
