import 'package:flutter/material.dart';

import 'landing_app_download.dart';
import 'landing_footer.dart';
import 'landing_header.dart';

export 'landing_app_download.dart';

const Color kLandingBg = Color(0xFFFFF8FB);

/// 랜딩 공통 3단 Scaffold — 메인 랜딩 페이지용
/// 구조: 헤더 + 콘텐츠(슬라이버) + 사이트정보 푸터
class LandingScaffold extends StatelessWidget {
  const LandingScaffold({
    super.key,
    required this.slivers,
    this.backgroundColor = kLandingBg,
    this.floatingActionButton,
  });

  final List<Widget> slivers;
  final Color backgroundColor;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      floatingActionButton: floatingActionButton,
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: LandingHeader()),
          ...slivers,
          const SliverToBoxAdapter(child: LandingFooter()),
        ],
      ),
    );
  }
}

/// 기능 페이지 4단 Scaffold — 모든 /features/* 페이지용
/// 구조: 헤더 + 바디(2단) + 앱다운로드(푸터1) + 사이트정보(푸터2)
class LandingFeatureScaffold extends StatelessWidget {
  const LandingFeatureScaffold({
    super.key,
    required this.slivers,
    this.backgroundColor = const Color(0xFFF8F6FF),
    this.floatingActionButton,
  });

  final List<Widget> slivers;
  final Color backgroundColor;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      floatingActionButton: floatingActionButton,
      body: CustomScrollView(
        slivers: [
          // 헤더 (TopBar + 활동스트립 + 프로모배너)
          const SliverToBoxAdapter(child: LandingHeader()),
          // 바디 (기능별 2단 콘텐츠)
          ...slivers,
          // 푸터1: 앱 다운로드
          const SliverToBoxAdapter(child: LandingAppDownload()),
          // 푸터2: 사이트 정보
          const SliverToBoxAdapter(child: LandingFooter()),
        ],
      ),
    );
  }
}
