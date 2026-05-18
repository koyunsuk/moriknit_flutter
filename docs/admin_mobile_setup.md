# 어드민 모바일 앱 (E안) — 빌드/배포 가이드

이슈: #815
방향: 별도 어드민 모바일 앱 + `lib/` 코드 100% 재사용 + 메인앱에 어드민 알림 위젯 추가.

본 PR 에서 추가된 것은 다음 3개입니다.

| 파일 | 목적 |
|---|---|
| `lib/main_admin_mobile.dart` | 어드민 모바일 entry (web `usePathUrlStrategy` 제거) |
| `lib/features/admin/presentation/widgets/admin_mobile_sidebar.dart` | 모바일 햄버거 Drawer 사이드바 |
| `lib/features/my/presentation/widgets/admin_alert_card.dart` | 메인앱(마이페이지) 어드민 알림 카드 |

## 1. 빌드 방법 (entry 분리만 사용 — 가장 간단한 경로)

```bash
# 디버그 APK (signing 동일)
flutter build apk --debug --target=lib/main_admin_mobile.dart

# 릴리즈 APK (signing 동일)
flutter build apk --release --target=lib/main_admin_mobile.dart

# 설치
/c/Users/koyunsuk/AppData/Local/Android/Sdk/platform-tools/adb.exe install -r \
  build/app/outputs/flutter-apk/app-debug.apk
```

iOS 도 동일 방식:

```bash
flutter build ipa --release --target=lib/main_admin_mobile.dart
```

> 본 단계까지는 `pubspec.yaml`, `android/app/build.gradle.kts`, `ios/Runner.xcodeproj` 어떤 파일도 수정하지 않음.
> 따라서 일반앱과 어드민앱이 **같은 applicationId / bundleId** 를 공유하며, 둘 다 설치 시 후행 설치가 선행 설치를 덮어씁니다.

## 2. (사용자 승인 필요) 어드민 앱을 별도 패키지로 분리

엔트리만 다른 별도 앱으로 배포하려면 Flavor 또는 applicationId 분기가 필요합니다.

### Android — `android/app/build.gradle.kts`

```kotlin
android {
    flavorDimensions += listOf("app")
    productFlavors {
        create("main") {
            dimension = "app"
            applicationId = "com.moriknit.app"
        }
        create("admin") {
            dimension = "app"
            applicationId = "com.moriknit.admin"
            versionNameSuffix = "-admin"
        }
    }
}
```

빌드 명령:

```bash
flutter build apk --debug --flavor admin --target=lib/main_admin_mobile.dart
flutter build apk --debug --flavor main  --target=lib/main.dart
```

### iOS — Xcode Schemes

- Runner 프로젝트에 `Runner-Admin` Scheme 추가
- `PRODUCT_BUNDLE_IDENTIFIER`: `com.moriknit.admin`
- Info.plist 의 `CFBundleDisplayName`: "MoriKnit Admin"

> 이 변경은 **사용자 승인 후 메인 세션에서 진행**합니다. 본 PR 에서는 적용하지 않음.

## 3. (사용자 승인 필요) admin_screen.dart 모바일 분기 통합

`lib/features/admin/presentation/admin_screen.dart` 의 `_AdminConsole.build()` 에
`LayoutBuilder` 를 추가해 좁은 폭에서 Drawer 모드로 전환:

```dart
return LayoutBuilder(
  builder: (context, constraints) {
    final isMobile = constraints.maxWidth < 720;
    if (isMobile) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        drawer: AdminMobileSidebar(
          navItems: _navItems
              .map((it) => it.isGroup
                  ? AdminMobileNavItem.group(
                      label: it.label,
                      color: it.color,
                      groupIcon: it.icon,
                    )
                  : AdminMobileNavItem.tab(
                      index: it.tabIndex!,
                      icon: it.icon!,
                      label: it.label,
                      color: it.color,
                    ))
              .toList(),
          selectedIndex: _selectedIndex,
          user: widget.user,
          onSelect: (i) {
            setState(() => _selectedIndex = i);
            Navigator.of(context).pop(); // Drawer 닫기
          },
        ),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E293B),
          foregroundColor: Colors.white,
          title: Text(_currentPageLabel),
        ),
        body: _buildContent(),
      );
    }
    // 기존 데스크탑 레이아웃 (Row + _AdminSidebar) 유지
    return Row(...);
  },
);
```

> 이 통합은 **메인 세션에서 사용자 승인 후 진행**. 본 PR 의 `admin_mobile_sidebar.dart` 는 단독 위젯으로만 추가되어 기존 동작에 영향이 없습니다.

## 4. 메인앱 어드민 알림 카드 노출

`lib/features/my/presentation/my_page_screen.dart` 에 다음 한 줄을 추가:

```dart
import 'widgets/admin_alert_card.dart';

// _MyPageBody build 내 적절한 위치 (예: 내 프로필 추가 정보 블록 위)
const AdminAlertCard(),
const SizedBox(height: 16),
```

- `isAdminProvider` 가드가 위젯 내부에 들어있어 비관리자에게는 자동으로 숨김 (`SizedBox.shrink()`).
- Custom Claims 의 `admin: true` 기준이므로 일반 사용자 노출 위험 없음.

## 5. 딥링크 설정 (사용자 승인 필요)

`admin_alert_card.dart` 의 "전체 어드민 열기" 는 `moriknitadmin://` deep link 를 시도합니다.
실제 동작하려면 어드민 모바일 앱에 다음 설정이 필요합니다.

### Android — `android/app/src/main/AndroidManifest.xml`

```xml
<intent-filter android:autoVerify="false">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="moriknitadmin" />
</intent-filter>
```

### iOS — `ios/Runner/Info.plist`

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array><string>moriknitadmin</string></array>
    </dict>
</array>
```

> 본 PR 에서는 적용하지 않음. 폴백으로 `https://admin.moriknit.com` 이 항상 열리므로 기능 자체는 동작.

## 6. FCM 어드민 토픽 (향후 작업 — 본 PR 외)

목표: 새 버그리포트 / 신규 1:1문의 등록 시 어드민 모바일 앱에 푸시.

### 6-a. 어드민 앱 초기화 시 토픽 구독

```dart
// main_admin_mobile.dart 의 main() 내부, runApp 직전 권장 위치
await FirebaseMessaging.instance.subscribeToTopic('admin-alerts');
```

### 6-b. Cloud Function (`functions/index.js` 또는 `index.ts`)

```ts
import {onDocumentCreated} from 'firebase-functions/v2/firestore';
import {getMessaging} from 'firebase-admin/messaging';

export const notifyAdminOnBugReport = onDocumentCreated(
  'bug_reports/{docId}',
  async (event) => {
    const data = event.data?.data();
    await getMessaging().send({
      topic: 'admin-alerts',
      notification: {
        title: '🐞 새 버그리포트',
        body: data?.title ?? '제목 없음',
      },
      data: {
        type: 'bug_report',
        docId: event.params.docId,
      },
    });
  },
);
```

`inquiries` 컬렉션(`landing_boards/qa/posts`)에도 동일 패턴으로 트리거 작성.

### 6-c. 알림 권한·핸들러

- iOS: `firebase_messaging` 의 `requestPermission()` 호출.
- Android 13+: `POST_NOTIFICATIONS` 권한 요청.
- foreground/background 핸들러에서 `data.type` 별 라우팅 (예: bug_report → tab index 11).

> 위 6번 항목은 본 PR 외 별도 이슈로 처리합니다.

## 7. 검증 체크리스트

- [ ] `flutter analyze lib/main_admin_mobile.dart lib/features/admin/presentation/widgets/admin_mobile_sidebar.dart lib/features/my/presentation/widgets/admin_alert_card.dart` 에러 0
- [ ] `flutter build apk --debug --target=lib/main_admin_mobile.dart` 성공
- [ ] 메인앱 빌드(기존 `lib/main.dart`)에 회귀 없음
- [ ] 웹 어드민(`lib/main_admin.dart`) 빌드에 회귀 없음 — 본 PR 은 해당 파일 미수정
