#!/usr/bin/env bash
# ⛔ 모리니트 모바일 빌드·설치 안전 스크립트 (이슈 #815/#816)
#
# 절대 규칙: 모바일유저 앱이 모바일어드민/셀러로 덮어씌워지지 않도록 보장.
# 반드시 이 스크립트로만 빌드/설치할 것. flutter build apk 직접 호출 금지.
#
# 사용법:
#   bash deploy_mobile.sh user      # 모바일유저 (MoriKnit) 빌드 + 설치
#   bash deploy_mobile.sh admin     # 모바일어드민 (모리니트 어드민) 빌드 + 설치
#   bash deploy_mobile.sh seller    # 모바일셀러 (모리니트 셀러) 빌드 + 설치
#   bash deploy_mobile.sh build_user        # 빌드만 (설치 X)
#   bash deploy_mobile.sh install_user      # 설치만 (빌드 X)
#
# 안전장치:
#   1. flavor 강제 명시 (혼합 빌드 방지)
#   2. APK 파일명 검증 (각 앱은 다른 산출물 파일 사용)
#   3. APK 패키지명 검증 (설치 직전 aapt로 확인)
#   4. 사용자 앱 보호: install_admin/install_seller는 절대 사용자 APK를 건드리지 않음

set -e  # 에러 발생 시 즉시 중단

ADB="/c/Users/koyunsuk/AppData/Local/Android/Sdk/platform-tools/adb.exe"
APK_DIR="build/app/outputs/flutter-apk"

# ── 빌드 함수들 ───────────────────────────────────────────────────────────────

build_user() {
  echo "▶ [모바일유저] flutter build apk --flavor user --target=lib/main.dart"
  echo "  → 산출물: $APK_DIR/app-user-debug.apk"
  flutter build apk --debug --flavor user --target=lib/main.dart
  echo "✅ 모바일유저 빌드 완료"
}

build_admin() {
  echo "▶ [모바일어드민] flutter build apk --flavor admin --target=lib/main_admin_mobile.dart"
  echo "  → 산출물: $APK_DIR/app-admin-debug.apk"
  flutter build apk --debug --flavor admin --target=lib/main_admin_mobile.dart
  echo "✅ 모바일어드민 빌드 완료"
}

build_seller() {
  echo "▶ [모바일셀러] flutter build apk --flavor seller --target=lib/main_seller_mobile.dart"
  echo "  → 산출물: $APK_DIR/app-seller-debug.apk"
  flutter build apk --debug --flavor seller --target=lib/main_seller_mobile.dart
  echo "✅ 모바일셀러 빌드 완료"
}

# ── 설치 함수들 (각자 자기 APK만, 패키지 검증) ──────────────────────────────────

verify_apk_package() {
  local apk_path=$1
  local expected_pkg=$2
  if [ ! -f "$apk_path" ]; then
    echo "❌ APK 파일 없음: $apk_path"
    exit 1
  fi
  # aapt 없으면 그냥 진행 (Android SDK build-tools 필요)
  local aapt
  aapt=$(ls /c/Users/koyunsuk/AppData/Local/Android/Sdk/build-tools/*/aapt.exe 2>/dev/null | sort -V | tail -1 || echo "")
  if [ -z "$aapt" ]; then
    echo "⚠️ aapt 미발견 — 패키지 검증 생략"
    return 0
  fi
  local actual_pkg
  # awk로 첫 번째 ^package: 라인의 'name=...' 두번째 필드 추출 (sed greedy 회피)
  actual_pkg=$("$aapt" dump badging "$apk_path" 2>/dev/null | awk -F"'" '/^package: name=/{print $2; exit}')
  if [ "$actual_pkg" != "$expected_pkg" ]; then
    echo "❌ 패키지 불일치! 기대: $expected_pkg / 실제: $actual_pkg"
    echo "  → 잘못된 APK를 설치하려고 합니다. 중단."
    exit 1
  fi
  echo "✅ 패키지 검증: $actual_pkg"
}

install_user() {
  local apk="$APK_DIR/app-user-debug.apk"
  # flavor 도입 전 기존 'app-debug.apk' 도 호환 (flavor 없이 빌드 시)
  [ ! -f "$apk" ] && [ -f "$APK_DIR/app-debug.apk" ] && apk="$APK_DIR/app-debug.apk"
  echo "▶ [모바일유저] adb install -r $apk"
  verify_apk_package "$apk" "com.moriknit.moriknit_flutter"
  "$ADB" install -r "$apk"
  echo "✅ 모바일유저 설치 완료"
}

install_admin() {
  local apk="$APK_DIR/app-admin-debug.apk"
  echo "▶ [모바일어드민] adb install -r $apk"
  verify_apk_package "$apk" "com.moriknit.admin_mobile"
  "$ADB" install -r "$apk"
  echo "✅ 모바일어드민 설치 완료"
}

install_seller() {
  local apk="$APK_DIR/app-seller-debug.apk"
  echo "▶ [모바일셀러] adb install -r $apk"
  verify_apk_package "$apk" "com.moriknit.android.seller"
  "$ADB" install -r "$apk"
  echo "✅ 모바일셀러 설치 완료"
}

# ── 메인 진입점 ───────────────────────────────────────────────────────────────

case "${1:-}" in
  user)         build_user;   install_user   ;;
  admin)        build_admin;  install_admin  ;;
  seller)       build_seller; install_seller ;;
  build_user)   build_user    ;;
  build_admin)  build_admin   ;;
  build_seller) build_seller  ;;
  install_user)   install_user   ;;
  install_admin)  install_admin  ;;
  install_seller) install_seller ;;
  *)
    echo "사용법: bash deploy_mobile.sh {user|admin|seller|build_*|install_*}"
    echo ""
    echo "  user     - 모바일유저 (com.moriknit.moriknit_flutter) 빌드 + 설치"
    echo "  admin    - 모바일어드민 (com.moriknit.admin_mobile) 빌드 + 설치"
    echo "  seller   - 모바일셀러 (com.moriknit.android.seller) 빌드 + 설치"
    exit 1
    ;;
esac

echo ""
echo "🎉 완료. 디바이스 설치된 모리니트 앱:"
"$ADB" shell pm list packages | grep moriknit || true
