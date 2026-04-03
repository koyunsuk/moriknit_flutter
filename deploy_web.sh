#!/usr/bin/env bash
# MoriKnit 웹 빌드 + Firebase 배포 스크립트
# 반드시 이 스크립트로만 웹 배포할 것 (수동 flutter build web 금지)
# 이유: --output 미지정 시 build/web에 덮어써져 앱/어드민 빌드가 교차 배포됨

set -e  # 에러 발생 시 즉시 중단

TARGET=${1:-"both"}  # 인자: app | admin | both (기본값: both)

build_app() {
  echo "▶ [1/2] 앱 빌드 → build/web"
  flutter build web --target lib/main.dart
  echo "✅ 앱 빌드 완료"
}

build_admin() {
  echo "▶ [2/2] 어드민 빌드 → build/web_admin"
  flutter build web --target lib/main_admin.dart --output build/web_admin
  echo "✅ 어드민 빌드 완료"
}

case "$TARGET" in
  app)
    build_app
    firebase deploy --only hosting:app
    ;;
  admin)
    build_admin
    firebase deploy --only hosting:admin
    ;;
  both)
    build_app
    build_admin
    firebase deploy --only hosting
    ;;
  *)
    echo "사용법: ./deploy_web.sh [app|admin|both]"
    exit 1
    ;;
esac

echo "🚀 Firebase 배포 완료"
