// 이슈 #704 Phase 4 — 충돌 해결 다이얼로그.
//
// ConflictPolicy.manual 케이스에서 사용자가 직접 로컬/서버/머지 중 선택.
// - 좌(로컬): 디바이스 아이콘 + 변경 시각 + 필드 값
// - 우(서버): 클라우드 아이콘 + 변경 시각 + 필드 값
// - 하단 액션: [로컬 유지] [서버 채택] [필드별 머지]
// - 필드별 머지: 각 필드 옆 라디오 (로컬/서버 선택)
//
// TData는 어떤 도메인 모델이든 가능. 호출자는 labelOf / fieldsOf / mergeBuilder 를 제공.
// (T는 typography 토큰이므로 제네릭 이름은 TData로 사용)

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// 필드별 머지 시 한 필드를 로컬/서버 중 어디서 가져올지.
enum FieldSide { local, server }

/// 충돌 해결 다이얼로그 (제네릭).
///
/// [TData] 는 어떤 도메인 모델이든 가능.
///
/// 호출:
/// ```dart
/// final winner = await showConflictResolutionDialog<MyModel>(
///   context: context,
///   title: '스와치 충돌',
///   local: localModel,
///   server: serverModel,
///   labelOf: (m) => m.name,
///   fieldsOf: (m) => {'이름': m.name, '게이지': '${m.gauge}'},
///   updatedAtOf: (m) => m.updatedAt,
///   mergeBuilder: (base, server, sideMap) => ...,
/// );
/// ```
class ConflictResolutionDialog<TData> extends StatefulWidget {
  final String title;
  final TData local;
  final TData server;

  /// 좌/우 카드 상단 라벨 (예: 항목명).
  final String Function(TData) labelOf;

  /// 필드 비교용 (key: 필드명, value: 표시 문자열).
  final Map<String, String> Function(TData) fieldsOf;

  /// 변경 시각 (좌/우 표기용). null이면 표시 X.
  final DateTime? Function(TData)? updatedAtOf;

  /// 필드별 머지 결과를 적용해 새 TData를 반환.
  /// `sideMap` 은 fieldsOf의 key 기준으로, 사용자가 어느 쪽을 선택했는지 표시한 map.
  ///
  /// 기본 베이스는 로컬. null이면 머지 버튼 비활성화.
  final TData Function(
      TData baseLocal, TData server, Map<String, FieldSide> sideMap)?
      mergeBuilder;

  const ConflictResolutionDialog({
    super.key,
    required this.title,
    required this.local,
    required this.server,
    required this.labelOf,
    required this.fieldsOf,
    this.updatedAtOf,
    this.mergeBuilder,
  });

  @override
  State<ConflictResolutionDialog<TData>> createState() =>
      _ConflictResolutionDialogState<TData>();
}

class _ConflictResolutionDialogState<TData>
    extends State<ConflictResolutionDialog<TData>> {
  /// 머지 모드 펼침 여부.
  bool _expanded = false;

  /// 필드별 선택 (기본: 모두 로컬).
  late final Map<String, FieldSide> _sideMap = {
    for (final k in widget.fieldsOf(widget.local).keys) k: FieldSide.local,
  };

  @override
  Widget build(BuildContext context) {
    final localFields = widget.fieldsOf(widget.local);
    final serverFields = widget.fieldsOf(widget.server);
    final allKeys = <String>{...localFields.keys, ...serverFields.keys}.toList();

    return AlertDialog(
      backgroundColor: C.gx,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(widget.title, style: AppTextStyles.h3),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 상단: 좌(로컬) / 우(서버) 카드
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _SideCard(
                      icon: Icons.phone_iphone,
                      iconColor: C.lv,
                      heading: '로컬 (이 기기)',
                      subheading: widget.labelOf(widget.local),
                      timestamp: widget.updatedAtOf?.call(widget.local),
                      fields: localFields,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SideCard(
                      icon: Icons.cloud_outlined,
                      iconColor: C.pk,
                      heading: '서버 (클라우드)',
                      subheading: widget.labelOf(widget.server),
                      timestamp: widget.updatedAtOf?.call(widget.server),
                      fields: serverFields,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_expanded && widget.mergeBuilder != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: C.bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: C.bd),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('필드별 선택', style: AppTextStyles.bodyBold),
                      const SizedBox(height: 8),
                      for (final k in allKeys)
                        _FieldRow(
                          fieldKey: k,
                          localValue: localFields[k] ?? '-',
                          serverValue: serverFields[k] ?? '-',
                          side: _sideMap[k] ?? FieldSide.local,
                          onChanged: (s) =>
                              setState(() => _sideMap[k] = s),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actionsPadding:
          const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text('취소', style: AppTextStyles.body.copyWith(color: C.mu)),
        ),
        if (widget.mergeBuilder != null)
          TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            child: Text(
              _expanded ? '머지 접기' : '필드별 머지',
              style: AppTextStyles.body.copyWith(color: C.lvD),
            ),
          ),
        _ActionButton(
          label: '서버 채택',
          color: C.pk,
          onTap: () => Navigator.of(context).pop(widget.server),
        ),
        _ActionButton(
          label: '로컬 유지',
          color: C.lv,
          onTap: () => Navigator.of(context).pop(widget.local),
        ),
        if (_expanded && widget.mergeBuilder != null)
          _ActionButton(
            label: '머지 적용',
            color: C.og,
            onTap: () {
              final merged = widget.mergeBuilder!(
                widget.local,
                widget.server,
                Map<String, FieldSide>.from(_sideMap),
              );
              Navigator.of(context).pop(merged);
            },
          ),
      ],
    );
  }
}

/// T 클래스의 타이포 토큰을 그대로 사용하지만,
/// 본 파일 내에서는 generic parameter 'T'가 가려지지 않도록 별칭 사용.
class AppTextStyles {
  static TextStyle get h3 => T.h3;
  static TextStyle get body => T.body;
  static TextStyle get bodyBold => T.bodyBold;
  static TextStyle get sm => T.sm;
  static TextStyle get caption => T.caption;
  static TextStyle get captionBold => T.captionBold;
}

class _SideCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String heading;
  final String subheading;
  final DateTime? timestamp;
  final Map<String, String> fields;

  const _SideCard({
    required this.icon,
    required this.iconColor,
    required this.heading,
    required this.subheading,
    required this.timestamp,
    required this.fields,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(heading,
                    style: AppTextStyles.captionBold.copyWith(color: iconColor)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subheading,
            style: AppTextStyles.bodyBold,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (timestamp != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(_formatTime(timestamp!),
                  style: AppTextStyles.caption.copyWith(color: C.mu)),
            ),
          const SizedBox(height: 6),
          Container(height: 1, color: iconColor.withValues(alpha: 0.18)),
          const SizedBox(height: 6),
          for (final entry in fields.entries) ...[
            Text(entry.key,
                style: AppTextStyles.caption
                    .copyWith(color: C.mu, fontSize: 10)),
            Text(
              entry.value,
              style: AppTextStyles.sm,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }

  static String _formatTime(DateTime dt) {
    final l = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${l.year}-${two(l.month)}-${two(l.day)} '
        '${two(l.hour)}:${two(l.minute)}';
  }
}

class _FieldRow extends StatelessWidget {
  final String fieldKey;
  final String localValue;
  final String serverValue;
  final FieldSide side;
  final ValueChanged<FieldSide> onChanged;

  const _FieldRow({
    required this.fieldKey,
    required this.localValue,
    required this.serverValue,
    required this.side,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(fieldKey, style: AppTextStyles.captionBold),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: _ChoiceTile(
                  selected: side == FieldSide.local,
                  color: C.lv,
                  label: '로컬',
                  value: localValue,
                  onTap: () => onChanged(FieldSide.local),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _ChoiceTile(
                  selected: side == FieldSide.server,
                  color: C.pk,
                  label: '서버',
                  value: serverValue,
                  onTap: () => onChanged(FieldSide.server),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  final bool selected;
  final Color color;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _ChoiceTile({
    required this.selected,
    required this.color,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.10) : C.gx,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : C.bd,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              size: 14,
              color: selected ? color : C.mu,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppTextStyles.caption.copyWith(
                          color: selected ? color : C.mu,
                          fontWeight: FontWeight.w700)),
                  Text(
                    value,
                    style: AppTextStyles.sm,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label,
          style: AppTextStyles.captionBold
              .copyWith(color: Colors.white, fontSize: 12)),
    );
  }
}

/// 헬퍼 함수.
///
/// [mergeBuilder] 가 제공되면 "필드별 머지" 버튼 활성화.
Future<TData?> showConflictResolutionDialog<TData>({
  required BuildContext context,
  required String title,
  required TData local,
  required TData server,
  required String Function(TData) labelOf,
  required Map<String, String> Function(TData) fieldsOf,
  DateTime? Function(TData)? updatedAtOf,
  TData Function(
          TData baseLocal, TData server, Map<String, FieldSide> sideMap)?
      mergeBuilder,
}) {
  return showDialog<TData>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ConflictResolutionDialog<TData>(
      title: title,
      local: local,
      server: server,
      labelOf: labelOf,
      fieldsOf: fieldsOf,
      updatedAtOf: updatedAtOf,
      mergeBuilder: mergeBuilder,
    ),
  );
}
