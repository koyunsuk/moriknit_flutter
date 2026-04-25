# MoriKnit Flutter - Claude 설정

## 🎯 제품 최종 도착점 (End State)

> 모든 구현 결정은 이 도착점을 기준으로 역산. 세션/에이전트 무관하게 항상 참조.

### 정체성
- **핵심**: 세계 최고의 니트 편집 툴 + 도안 마켓플레이스
- **온보딩 엔진**: PDF → AI 변환 (기존 PDF 사용자의 초기 진입로)
- **유통 계층**: Fork / 판매 / 커뮤니티 (complete 도안만)

### 자산 위계
```
[1층: 창작]  도안에디터 → 차트 + 서술형 + 섹션 = 완성된 .mori
[2층: 작업]  스와치 → 프로젝트 ← 도안 → 단계로그 · 카운터 · 타이머 (모두 자동 연결)
[3층: 유통]  마켓 · Fork · 커뮤니티 (complete 도안만)
[지하:온보딩] PDF → AI 변환 → draft 도안 → 편집툴 체험 → complete
```

### 자산 연결 원칙 (최종)
| From → To | 관계 |
|---|---|
| 도안 → 프로젝트 | 단계로그 자동 미러링 (sections → steps) |
| 단계 → 카운터 | 자동 연결 (projectStepId) |
| 도안 → 타이머 | 세션별 누적 (patternSession.totalSeconds) |
| 스와치 → 타이머 | 누적 시작점 (swatch.totalSeconds) |
| 프로젝트 → 타이머 | 집계 뷰 (sum of 도안+스와치) |
| complete 도안 | Fork/판매/공유 게이트 통과 |

### 도안 상태 모델
- `PatternChart.status: 'draft' | 'complete'`
- `draft`: 저장은 되지만 Fork/판매/공유 **불가**
- `complete`: aiSections(또는 수동 섹션) 1개 이상 보유 시 승격
- 기존 도안 마이그레이션: 전부 draft 전환 + 사용자 일괄 알림

### 로드맵 (역산 순서)
| # | 이슈 | 선결 | 상태 |
|---|---|---|---|
| 0 | #624 [공통] 도구함 독립 뜨개 타이머 (Facade) | - | 🔵 대기 |
| 1 | #625 [공통] 도안에디터 서술형 섹션 그룹화 UI | - | 🔵 대기 |
| 2 | #626 [공통] 도안 상태 모델 (draft/complete) + 마이그레이션 | #625 | 🔵 대기 |
| 3 | #627 [모바일][웹앱] AI 변환 도안 → 프로젝트 단계로그 자동 연결 | #626 | 🔵 대기 |
| 4 | #628 [모바일][웹앱] 도안 등록 진입점 3가지 간소화 UI | - | 🔵 대기 |
| 5 | #629 [공통] Fork/판매/공유 게이트 (complete 조건) | #626 | 🔵 대기 |
| 6 | #630 [모바일][웹앱] 스와치 타이머 + 프로젝트 시간 집계 대시보드 | - | 🔵 대기 |
| 7 | #631 [공통] 외부 클라우드 확장 (GDrive/iCloud/OneDrive) | #628 | 로드맵 |

### 도안 업로드 경로 (3가지 간소화)
1. **파일** (FilePicker)
2. **외부 클라우드** (현재 Dropbox만. 로드맵: GDrive/iCloud/OneDrive)
3. **도안에디터** (차트+서술형 직접 작성 → 섹션 그룹화)

### AI 변환 유도 정책
- 등록 시: "AI 자동 분석" 체크박스 기본 ON
- 프로젝트 연결 시 폴백: 단계 없는 도안 연결 → 배너 "AI 분석하시겠어요?"
- 재분석은 **같은 문서 덮어쓰기** (새 문서 생성 금지 — PatternSession 연결 유지)

---

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
- **모든 작업 지시(기능 추가, 버그 수정, UI 변경, 긴급 수정 포함)는 예외 없이 즉시 GitHub 이슈 생성** (repo: koyunsuk/moriknit_flutter)
- 이슈 미등록 상태로 작업 진행 절대 금지. 이슈 번호 없이 코드 수정 금지.
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
  3. **웹앱도 함께 빌드·배포**: `bash deploy_web.sh app` (앱 타깃만, 어드민 제외)
  4. Pushover 알림: title="📱 모리니트 설치 완료", message="모리니트 모바일 + 웹앱 신버전 설치/배포 완료. 확인해주세요"
  5. 해당 이슈 상태 🟢로 업데이트: `gh issue edit {N} --title "🟢 #N [카테고리] 제목"`
- 빌드/설치 완료 후 결과만 보고. 중간에 확인 요청 금지.
- **웹앱 코드 변경이 없어도** 모바일 빌드 시 웹앱 배포 항상 포함 (동기화 보장)

## iOS TestFlight 빌드 번호 규칙 (절대 준수)
- **Codemagic으로 iOS 빌드 전 반드시 `pubspec.yaml`의 빌드 번호를 +1 올릴 것**
- 현재 번호 확인: `grep "version:" pubspec.yaml`
- 번호 올리기: `sed -i 's/version: X.X.X+NNNN/version: X.X.X+NNNNN/' pubspec.yaml`
- 변경 후 커밋·푸시까지 완료 후 Codemagic 빌드 시작
- 같은 번호로 업로드 시 App Store Connect에서 거부됨 (이전 사고: 2004 중복)

## 웹 빌드·배포 → 상단 ⛔ 절대 규칙 섹션 참조

## 이슈 상태 업데이트 (절대 준수)
- **APK 설치 완료 시 무조건 실행**: 해당 작업의 모든 관련 이슈 상태를 🟢로 업데이트
- `gh issue edit {N} --title "🟢 ..."` 명령으로 신호등 이모지 교체
- 여러 이슈인 경우 병렬 실행
- **작업 완료 메시지 전송 시마다 반드시 GitHub 이슈 신호등 업데이트 후 전체 이슈 현황 보고**
  - 보고 순서: 🟢 완료 → 🟡 진행 중 → 🔴 긴급/차단 → 🟣 대기 → ⚪ 장기검토
  - 🟢 이번 빌드 포함 이슈: 앱에서 확인할 체크박스 항목 나열
  - 🟣 대기 중 이슈: 목록 표로 정리
  - ⚪ 장기 검토 이슈: 한줄 요약
  - 빌드/설치/배포할 때마다 매번 이 형식으로 보고 (생략 금지)

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
- **승인 대기 중인 항목 재질문 (필수):** 승인이 필요한 태스크에 사용자가 응답하지 않은 경우 (세션 전환, 무응답 등), 사용자가 모르고 지나쳤을 수 있으므로 **반드시 재차 질문**. 승인 없이 구현 진행 금지.

## ⛔ 제품 정책 결정 금지 (절대 준수)

> **2026-04-21 사고**: flutter_appauth 웹 미지원 제약을 만났을 때, 멈추고 질문하는 대신
> "웹에서는 Dropbox 연결을 지원하지 않아요. 모바일 앱을 이용해 주세요." 메시지를 임의로 추가.
> 기술적 제약을 이유로 **제품 기능 허용/차단 정책을 Claude가 독단적으로 결정**한 사고.

- **구현 방법** (어떻게 만드냐) → Claude가 결정, 바로 진행
- **제품 정책** (어떤 기능을 허용/차단/안내하냐) → 반드시 멈추고 개발자에게 질문
- 기술적 제약을 만났을 때: **개발자에게 제약 사실을 보고**하고, 처리 방식은 개발자가 결정
- **앱 사용자에게 노출되는** 에러 메시지·안내 문구·기능 차단 코드를 요청 없이 임의로 추가 금지
  - 잘못된 예: `state = state.copyWith(error: '웹에서는 지원하지 않아요. 모바일 앱을 이용해 주세요.')`
  - 올바른 예: 개발자에게 "flutter_appauth는 웹을 지원하지 않습니다. 어떻게 처리할까요?" 보고 후 대기

## ⛔ 기능 보존 원칙 (절대 준수 — 위반 시 즉시 복구)

> **2026-04-10 사고**: 홈화면 레이아웃 재구성 시 뜨개소식·모리채널 섹션(_EditorialBoard) 삭제됨.
> 레이아웃 변경이라도 **기존 섹션/위젯을 제거하는 것은 기능 삭제와 동일**.

- **기존 기능은 절대 삭제하지 않는다. 추가·확장만 허용.**
- **레이아웃 재구성 시 필수 체크**: 수정 전 섹션 목록을 먼저 나열하고, 수정 후 모두 존재하는지 대조 확인 후 진행.
- 에이전트가 파일을 수정할 때 기존 기능(라우팅, 네비게이션 링크, UI 섹션)이 제거되지 않았는지 반드시 확인.
- 기능 접근 경로(context.push/go)가 삭제되면 화면은 존재해도 사용자가 접근 불가 → 이것도 기능 삭제와 동일하게 금지.
- **홈화면 등 섹션 여러 개 포함 화면 수정 시**: 수정 전 섹션 이름 목록 → 수정 후 섹션 이름 목록 비교 표를 응답에 반드시 포함.

## 코드 품질
- 모든 코드는 재사용 및 유지보수가 용이하도록 최대한 모듈화.
- UI는 Shell 개념을 높은 중요도로 인지 (공통 Shell → 개별 화면 구성).
- UI / DB / Code 개념 분리 원칙 매우 중요.

## UI 원칙
- 저장 관련 UI 통일: "저장하는 중입니다." 작은 팝업 + 프로그레스 표시.
- 중복 버튼(저장, 새로만들기 등) 발견 시 삭제.
- 헤더는 공통 컴포넌드로 관리 (스와치/프로젝트/도안 등 통일성 유지).
- 기준 화면: 스와치 화면 → 모든 저장 화면의 UI 레퍼런스.
- **플레이스홀더 원칙 (절대 준수)**: 모든 UI 기능은 데이터가 없더라도 플레이스홀더로 공간을 고정 표시한다. `SizedBox.shrink()` 또는 데이터 없을 때 섹션 자체를 숨기는 것 금지. 빈 행 2~3개 + 안내 문구로 구성된 플레이스홀더 위젯을 항상 제공.

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

## 플랫폼별 네이티브 설정 체크리스트 (신규 기능 추가 시 필수)
- **OAuth/소셜 로그인 등 네이티브 연동 기능 추가 시 Android·iOS 양쪽 설정을 한 번에 완료할 것**
- 한 플랫폼만 설정하고 넘어가는 것 절대 금지
- **iOS 체크 항목**:
  - `Info.plist` URL Scheme / LSApplicationQueriesSchemes
  - `SceneDelegate.swift` openURLContexts 핸들러
  - `AppDelegate.swift` 필요 시 핸들러
- **Android 체크 항목**:
  - `AndroidManifest.xml` intent-filter / queries
  - 키 해시 등록 (카카오 등)
- 이전 사고: 카카오 로그인 구현 시 Android만 설정하고 iOS SceneDelegate URL 핸들러 누락 → iOS 로그인 불가 (2026-04-10)

## 에러 제로화 규칙 (모든 작업 완료 시 필수 단계)

### 규칙
- **모든 작업 완료 후 반드시 에러 0개 확인 후 빌드/배포 진행**
- `flutter analyze` 또는 IDE diagnostics에서 **error** 항목이 0개여야 함
- warning/hint는 기존 것은 허용하나 **새로 추가된 warning은 수정 후 진행**

### 확인 방법
```bash
flutter analyze lib/ 2>&1 | grep -E "^  error" | wc -l
# 결과가 0이어야 진행 가능
```

### 적용 시점
1. 코드 수정 완료 직후
2. APK 빌드 전
3. 웹 배포 전
4. Firebase Functions 배포 전

---

## 도메인 구조 (절대 변경 금지)

| 사이트 | 도메인 | Firebase Hosting Target |
|--------|--------|------------------------|
| 랜딩 | moriknit.com | landing (moriknit-landing) |
| 웹앱 | app.moriknit.com | app (moriknit-ceea9) |
| 어드민 | admin.moriknit.com | admin (moriknit-admin) |

⛔ `_mainAppUrl` 항상 `'https://app.moriknit.com'` — 절대 변경 금지

---

## ⛔ 코드 수정 최소화 원칙 (최우선 — 이슈 증가 방지)

> **회귀가 새로운 이슈를 만들고 있음. 기존에 작동하던 기능은 절대 건드리지 말 것.**

- **버그 수정 범위**: 보고된 버그가 있는 파일·함수·라인만 수정. 관련 없는 코드 일절 손대지 않음
- **UI 보존**: 작동 중인 UI 레이아웃·컴포넌트·섹션은 수정 지시 없으면 그대로 유지
- **수정 전 체크**: 해당 파일에서 이미 작동 중인 기능 목록 확인 후 수정 진행
- **Write 도구 사용 금지**: 기존 파일은 반드시 Edit 도구로 부분 수정만. Write로 전체 덮어쓰기 절대 금지
- **수정 후 체크**: 수정한 파일에서 기존 기능이 그대로 있는지 반드시 확인

## ⛔ 이전 커밋 덮어쓰기 금지 (절대 준수 — 2026-04-24 등록)

> 사용자가 명시적으로 요청하지 않는 한, 이미 커밋된 코드를 이전 버전으로 되돌리거나 덮어쓰지 않는다.

### 금지 행동
- ❌ `git reset --hard`, `git revert`, `git checkout <old-sha> -- file` 등 사용자 명시 요청 없이 실행 금지
- ❌ 옛 파일 내용으로 현재 파일 덮어쓰기 (Read로 옛 커밋 본 후 그대로 Write)
- ❌ "예전엔 이랬었지" 추측으로 기존 함수/위젯 동작을 이전 버전 패턴으로 되돌리기
- ❌ 변경 의도 불명확한 코드를 보고 "버그인 줄" 알고 옛 형태로 복원

### 의심 발생 시
- ✅ 사용자에게 질문 후 진행 ("이 코드는 #N 이슈 변경분인데 되돌릴까요?")
- ✅ git log / git blame으로 변경 의도 확인 후 신중하게 새 코드로 진화
- ✅ 회귀 가능성이 보이면 즉시 멈추고 사용자 확인

### 위반 시 조치
즉시 사용자에게 보고 + 변경된 파일 git diff 보여주기 + 복구 방안 제안.

### 사용자 명시 요청 인정 형식
"X 파일을 OO 커밋으로 되돌려" / "이전 버전으로 복구해" 같은 직접·구체적 표현만 인정.
"정리해" "원래대로" 같은 모호한 표현은 인정 안 함 — 한 번 더 확인.

## ⛔ 회귀 방지 — 확정된 구현 결정 (절대 되돌리지 말 것)

> 이 목록의 결정은 **이미 구현 완료됨**. 새 세션·에이전트라도 아래 항목을 다시 추가하거나 원래대로 되돌리는 것 **절대 금지**.

### 도안에디터 툴바 구조 (chart_toolbar.dart)
- ⛔ 색상/기호 구분 탭(LayerTab 행) **삭제 완료** → 다시 추가 금지
- ⛔ 툴바 2행 구조 → **1행 통합 완료** → 다시 2행으로 나누지 말 것
- ✅ 색상 팔레트: 항상 고정 표시 (기호 모드와 동시 표시)
- ✅ 기호 패널: 기본 표시 (DrawLayer.symbol 기본값)
- ✅ 구조: [기능툴바 1행] → [색상팔레트] → [기호패널]

### Firestore rules (firestore.rules)
- ✅ **git 추적 시작됨** (2026-04-18) — 반드시 변경 후 커밋
- ✅ `isAdmin()` 함수: `request.auth.token.email == 'koyunsuk@gmail.com'`
- ✅ 어드민 쓰기 허용 컬렉션: `landing_notices`, `builtin_templates`, `encyclopedia`, `courses`, `app_config`, `ui_copy`
- ⛔ `allow write: if false` 로 되돌리지 말 것 — 어드민 앱이 클라이언트 SDK 사용함

### 퀵버튼 뒤로가기 (main_shell.dart)
- ✅ `Navigator.maybePop` → `context.canPop() ? context.pop() : 없음` 으로 변경 완료
- ⛔ `Navigator.maybePop(context)` 로 되돌리지 말 것
