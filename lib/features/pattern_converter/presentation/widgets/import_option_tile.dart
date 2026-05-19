import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';

/// 이슈 #869 — 변환기/번역기 임포트 시트 옵션 카드 공통 위젯.
///
/// 모든 임포트 옵션(내 핸드폰 / 내 도안 라이브러리 / Dropbox / 외부 클라우드 준비중 /
/// 도안에디터 / 래글런 샘플)을 동일 톤(라벤더 기본)으로 렌더링하기 위한 공통 ListTile.
///
/// 톤 변경 시 이 파일 한 곳만 수정하면 두 화면(`pattern_converter_screen.dart`,
/// `pattern_translator_screen.dart`)에 즉시 반영된다.
class ImportOptionTile extends StatelessWidget {
  /// 좌측 아이콘 (예: Icons.smartphone_rounded)
  final IconData icon;

  /// 아이콘 색 (미지정 시 C.lvD)
  final Color? iconColor;

  /// 아이콘 배경색 (미지정 시 C.lvL)
  final Color? iconBackground;

  /// 타이틀 텍스트 (예: "내 핸드폰")
  final String title;

  /// 서브타이틀 텍스트 (예: "PDF, JPG, PNG")
  final String? subtitle;

  /// 탭 핸들러 — null이면 비활성(준비중) 표기는 caller가 처리
  final VoidCallback? onTap;

  /// 타이틀 뒤에 표시되는 작은 배지 (예: "준비 중"). null이면 표시 안함.
  final Widget? trailingBadge;

  /// 타이틀 색상 (준비중 카드는 C.mu, 일반은 기본 T.bodyBold 색상)
  final Color? titleColor;

  /// 우측 chevron 표시 여부 (기본 true). 준비중 카드는 false 권장.
  final bool showChevron;

  /// 좌측 들여쓰기 (ExpansionTile 내부 자식인 경우 16 사용).
  final double leftPadding;

  const ImportOptionTile({
    super.key,
    required this.icon,
    required this.title,
    this.iconColor,
    this.iconBackground,
    this.subtitle,
    this.onTap,
    this.trailingBadge,
    this.titleColor,
    this.showChevron = true,
    this.leftPadding = 0,
  });

  @override
  Widget build(BuildContext context) {
    final tile = ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: iconBackground ?? C.lvL,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor ?? C.lvD, size: 22),
      ),
      title: trailingBadge == null
          ? Text(
              title,
              style: titleColor == null
                  ? T.bodyBold
                  : T.bodyBold.copyWith(color: titleColor),
            )
          : Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: titleColor == null
                        ? T.bodyBold
                        : T.bodyBold.copyWith(color: titleColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                trailingBadge!,
              ],
            ),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: T.caption.copyWith(color: C.mu)),
      trailing: showChevron
          ? Icon(Icons.chevron_right_rounded, color: C.mu)
          : null,
      onTap: onTap,
    );
    if (leftPadding == 0) return tile;
    return Padding(
      padding: EdgeInsets.only(left: leftPadding),
      child: tile,
    );
  }
}

/// "준비 중" 배지 — 외부 클라우드 미지원 항목에 사용.
class ComingSoonBadge extends StatelessWidget {
  final bool isKorean;
  const ComingSoonBadge({super.key, required this.isKorean});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: C.bd2.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isKorean ? '준비 중' : 'Coming Soon',
        style: T.caption.copyWith(
          color: C.mu,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
