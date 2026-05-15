import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../providers/accessory_provider.dart';
import '../domain/accessory_model.dart';
import 'accessory_input_screen.dart';

class AccessoryDetailScreen extends ConsumerWidget {
  final String itemId;
  const AccessoryDetailScreen({super.key, required this.itemId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(accessoryListProvider);
    final item = listAsync.valueOrNull?.where((e) => e.id == itemId).firstOrNull;
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';

    if (item == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              MoriPageHeaderShell(
                child: MoriWideHeader(
                  title: isKorean ? '악세사리' : 'Accessory',
                  subtitle: isKorean ? '악세사리 상세' : 'Accessory details',
                ),
              ),
              Expanded(
                child: Center(child: Text(isKorean ? '항목을 찾을 수 없어요.' : 'Item not found.', style: T.body)),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const BgOrbs(),
          SafeArea(
            child: Column(
              children: [
                MoriPageHeaderShell(
                  child: MoriWideHeader(
                    title: item.localizedTypeLabel(isKorean),
                    subtitle: isKorean ? '악세사리 상세' : 'Accessory details',
                    trailing: [
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: C.tx),
                        onSelected: (v) async {
                          if (v == 'edit') {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => AccessoryInputScreen(initialItem: item)));
                          } else if (v == 'delete') {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text(isKorean ? '삭제하시겠어요?' : 'Delete?'),
                                content: Text(isKorean ? '이 악세사리를 삭제해요.' : 'This accessory will be deleted.'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isKorean ? '취소' : 'Cancel')),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: Text(isKorean ? '삭제' : 'Delete', style: TextStyle(color: C.og)),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true && context.mounted) {
                              try {
                                await runWithMoriLoadingDialog<void>(
                                  context,
                                  message: isKorean ? '삭제하는 중입니다.' : 'Deleting...',
                                  subtitle: isKorean ? '잠시만 기다려 주세요.' : 'Please wait.',
                                  task: () => ref.read(accessoryRepositoryProvider).deleteAccessory(item.id),
                                );
                                if (context.mounted) Navigator.pop(context);
                              } catch (e) {
                                if (!context.mounted) return;
                                final msg = e.toString();
                                final friendly = (msg.contains('인터넷') || msg.contains('TimeoutException'))
                                    ? (isKorean ? '인터넷 연결을 확인해 주세요' : 'Check your internet connection')
                                    : msg;
                                showSaveErrorSnackBar(ScaffoldMessenger.of(context), message: friendly);
                              }
                            }
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(value: 'edit', child: Text(isKorean ? '수정' : 'Edit')),
                          PopupMenuItem(value: 'delete', child: Text(isKorean ? '삭제' : 'Delete', style: TextStyle(color: C.og))),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 히어로 카드
                GlassCard(
                  child: Row(
                    children: [
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          color: C.pkL,
                          borderRadius: BorderRadius.circular(16),
                          image: item.photoUrl.isNotEmpty
                              ? DecorationImage(image: NetworkImage(item.photoUrl), fit: BoxFit.cover)
                              : null,
                        ),
                        child: item.photoUrl.isEmpty
                            ? Icon(Icons.build_rounded, color: C.pkD, size: 36)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.localizedTypeLabel(isKorean), style: T.h3),
                            if (item.brandName.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(item.brandName, style: T.body.copyWith(color: C.mu)),
                            ],
                            if (item.name.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(item.name, style: T.caption.copyWith(color: C.mu)),
                            ],
                            const SizedBox(height: 8),
                            Wrap(spacing: 6, children: [
                              _InfoChip(label: isKorean ? '${item.quantity}개' : '×${item.quantity}', icon: Icons.layers_rounded, color: C.pkD),
                              if (item.price > 0)
                                _InfoChip(label: '₩${NumberFormat('#,###').format(item.price)}', icon: Icons.sell_rounded, color: C.lmD),
                            ]),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 구매 정보
                if (item.purchasePlace.isNotEmpty || item.purchaseDate != null)
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isKorean ? '구매 정보' : 'Purchase Info', style: T.bodyBold),
                        const SizedBox(height: 10),
                        if (item.purchasePlace.isNotEmpty)
                          _DetailRow(icon: Icons.store_rounded, label: isKorean ? '구매처' : 'Store', value: item.purchasePlace),
                        if (item.purchaseDate != null)
                          _DetailRow(icon: Icons.calendar_today_rounded, label: isKorean ? '구매일' : 'Date',
                              value: DateFormat('yyyy.MM.dd').format(item.purchaseDate!)),
                      ],
                    ),
                  ),

                // 메모
                if (item.memo.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isKorean ? '📝 메모' : '📝 Memo', style: T.bodyBold),
                        const SizedBox(height: 8),
                        Text(item.memo, style: T.body.copyWith(color: C.mu)),
                      ],
                    ),
                  ),
                ],

                // 날짜
                const SizedBox(height: 12),
                GlassCard(
                  child: Column(
                    children: [
                      if (item.createdAt != null)
                        _DetailRow(icon: Icons.add_circle_outline_rounded, label: isKorean ? '등록일' : 'Created',
                            value: DateFormat('yyyy.MM.dd').format(item.createdAt!)),
                      if (item.updatedAt != null)
                        _DetailRow(icon: Icons.edit_calendar_rounded, label: isKorean ? '수정일' : 'Updated',
                            value: DateFormat('yyyy.MM.dd').format(item.updatedAt!)),
                    ],
                  ),
                ),
              ],
            ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _InfoChip({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: C.mu),
          const SizedBox(width: 8),
          Text(label, style: T.caption.copyWith(color: C.mu)),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: T.body, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
