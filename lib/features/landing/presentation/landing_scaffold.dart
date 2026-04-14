import 'package:flutter/material.dart';

import 'landing_footer.dart';
import 'landing_header.dart';

const Color kLandingBg = Color(0xFFFFF8FB);

/// 랜딩 공통 3단 Scaffold (Header + 스크롤 바디 + Footer)
///
/// 사용 예:
/// ```dart
/// LandingScaffold(
///   slivers: [
///     SliverToBoxAdapter(child: MySection()),
///   ],
/// )
/// ```
class LandingScaffold extends StatelessWidget {
  const LandingScaffold({
    super.key,
    required this.slivers,
    this.backgroundColor = kLandingBg,
    this.floatingActionButton,
  });

  /// 헤더·푸터를 제외한 콘텐츠 Sliver 목록
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
          // 공통 헤더 (TopBar + 활동스트립 + 프로모배너)
          const SliverToBoxAdapter(child: LandingHeader()),
          // 콘텐츠 영역
          ...slivers,
          // 공통 푸터
          const SliverToBoxAdapter(child: LandingFooter()),
        ],
      ),
    );
  }
}
