// 이슈 #845 — DM 첨부 파일 칩 (비이미지 PDF/문서 등).
//
// 어드민이 사용자에게 보낸 첨부 파일(또는 그 역)을 채팅 버블 안에
// 작은 칩 형태로 표시. 탭 시 외부 브라우저로 URL 오픈.
//
// 사용 위치:
//   - lib/features/admin/presentation/widgets/inbox/inbox_chat_panel.dart
//   - lib/features/dm/presentation/dm_chat_screen.dart
//
// 색상/타이포는 항상 토큰(C/T) 사용. 직접 Color/TextStyle 금지.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode, launchUrl;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';

class DmAttachmentChip extends StatelessWidget {
  /// 첨부 파일의 다운로드 URL (Firebase Storage 등).
  final String url;
  /// 표시명. 비어있으면 URL 의 끝부분(파일명) 추출 사용.
  final String name;
  /// 버블이 어드민(라벤더 배경) 측인지 — true 면 흰색 톤, false 면 라벤더 톤.
  final bool isAdminSide;
  /// 한국어 UI 여부 (툴팁/aria 라벨용).
  final bool isKorean;

  const DmAttachmentChip({
    super.key,
    required this.url,
    required this.name,
    required this.isAdminSide,
    this.isKorean = true,
  });

  String get _displayName {
    if (name.isNotEmpty) return name;
    final uri = Uri.tryParse(url);
    final segs = uri?.pathSegments ?? const <String>[];
    if (segs.isEmpty) return isKorean ? '첨부 파일' : 'Attachment';
    final last = Uri.decodeComponent(segs.last);
    // Storage URL 의 마지막 세그먼트는 'dm/admin_attachments/.../1234_file.pdf' 의
    // 끝부분 'file.pdf' 만 표시.
    final i = last.contains('_') ? last.indexOf('_') + 1 : 0;
    return last.substring(i);
  }

  IconData get _iconForFile {
    final lower = _displayName.toLowerCase();
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf_outlined;
    if (lower.endsWith('.doc') || lower.endsWith('.docx')) {
      return Icons.description_outlined;
    }
    if (lower.endsWith('.xls') || lower.endsWith('.xlsx')) {
      return Icons.table_chart_outlined;
    }
    if (lower.endsWith('.zip') || lower.endsWith('.7z')) {
      return Icons.folder_zip_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  Future<void> _open() async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    // 어드민 버블(라벤더 배경)에서는 흰색 반투명 칩, 일반 버블에서는 라벤더 칩.
    final bg = isAdminSide
        ? Colors.white.withValues(alpha: 0.18)
        : C.lvL;
    final fg = isAdminSide ? Colors.white : C.lvD;
    final borderColor = isAdminSide
        ? Colors.white.withValues(alpha: 0.32)
        : C.lv.withValues(alpha: 0.30);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _open,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_iconForFile, color: fg, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: T.body.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.open_in_new_rounded, color: fg, size: 14),
          ],
        ),
      ),
    );
  }
}
