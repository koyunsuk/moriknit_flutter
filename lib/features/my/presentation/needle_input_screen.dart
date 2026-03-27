import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/needle_provider.dart';
import '../domain/needle_model.dart';

class NeedleInputScreen extends ConsumerStatefulWidget {
  final NeedleModel? initialNeedle;

  const NeedleInputScreen({super.key, this.initialNeedle});

  @override
  ConsumerState<NeedleInputScreen> createState() => _NeedleInputScreenState();
}

class _NeedleInputScreenState extends ConsumerState<NeedleInputScreen> {
  bool _isSaving = false;
  late final TextEditingController _brandCtrl;
  late final TextEditingController _memoCtrl;

  @override
  void initState() {
    super.initState();
    final needle = widget.initialNeedle;
    _brandCtrl = TextEditingController(text: needle?.brandName ?? '');
    _memoCtrl = TextEditingController(text: needle?.memo ?? '');

    if (needle != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(needleInputProvider.notifier).load(needle);
      });
    }
  }

  @override
  void dispose() {
    _brandCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final needle = ref.watch(needleInputProvider);
    final notifier = ref.read(needleInputProvider.notifier);
    final isKorean = ref.watch(appLanguageProvider).isKorean;

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: C.tx, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.initialNeedle == null
              ? (isKorean ? '바늘 추가' : 'Add Needle')
              : (isKorean ? '바늘 수정' : 'Edit Needle'),
          style: T.h3,
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : () => _save(context, isKorean),
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: C.lv),
                  )
                : Text(isKorean ? '저장' : 'Save', style: T.bodyBold.copyWith(color: C.lv)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionLabel(isKorean ? '바늘 사이즈 *' : 'Needle size *'),
            const SizedBox(height: 10),
            _NeedleSizeSelector(
              selectedSize: needle.size,
              onSelected: notifier.setSize,
            ),
            const SizedBox(height: 20),
            _SectionLabel(isKorean ? '종류' : 'Type'),
            const SizedBox(height: 10),
            _SegmentedSelector(
              options: [
                ('straight', isKorean ? '일반바늘' : 'Straight'),
                ('circular', isKorean ? '줄바늘' : 'Circular'),
                ('dpn', isKorean ? '양두바늘' : 'Double-pointed'),
                ('cable', isKorean ? '케이블 바늘' : 'Cable'),
              ],
              selected: needle.type,
              color: C.lv,
              onSelected: notifier.setType,
            ),
            const SizedBox(height: 20),
            _SectionLabel(isKorean ? '소재' : 'Material'),
            const SizedBox(height: 10),
            _SegmentedSelector(
              options: [
                ('bamboo', isKorean ? '대나무' : 'Bamboo'),
                ('metal', isKorean ? '금속' : 'Metal'),
                ('wood', isKorean ? '나무' : 'Wood'),
                ('plastic', isKorean ? '플라스틱' : 'Plastic'),
              ],
              selected: needle.material,
              color: C.pk,
              onSelected: notifier.setMaterial,
            ),
            const SizedBox(height: 20),
            _SectionLabel(isKorean ? '브랜드 (선택)' : 'Brand (optional)'),
            const SizedBox(height: 8),
            TextField(
              controller: _brandCtrl,
              onChanged: notifier.setBrand,
              decoration: _inputDecoration(
                isKorean ? '브랜드명' : 'Brand name',
                isKorean: isKorean,
              ),
            ),
            const SizedBox(height: 20),
            _SectionLabel(isKorean ? '수량' : 'Quantity'),
            const SizedBox(height: 10),
            Row(
              children: [
                _QuantityButton(
                  icon: Icons.remove,
                  onTap: () {
                    if (needle.quantity > 1) {
                      notifier.setQuantity(needle.quantity - 1);
                    }
                  },
                ),
                const SizedBox(width: 16),
                Text(
                  isKorean ? '${needle.quantity}개' : '${needle.quantity}',
                  style: T.bodyBold,
                ),
                const SizedBox(width: 16),
                _QuantityButton(
                  icon: Icons.add,
                  filled: true,
                  onTap: () => notifier.setQuantity(needle.quantity + 1),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionLabel(isKorean ? '메모 (선택)' : 'Memo (optional)'),
            const SizedBox(height: 8),
            TextField(
              controller: _memoCtrl,
              maxLines: 2,
              onChanged: notifier.setMemo,
              decoration: _inputDecoration(
                isKorean ? '색상, 길이, 특이사항...' : 'Color, length, notes...',
                isKorean: isKorean,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, {required bool isKorean}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: T.body.copyWith(color: C.mu),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: C.bd2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: C.lv),
      ),
      filled: true,
      fillColor: C.gx,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Future<void> _save(BuildContext context, bool isKorean) async {
    final notifier = ref.read(needleInputProvider.notifier);
    final error = notifier.validationError;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: C.og),
      );
      return;
    }

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final needle = ref.read(needleInputProvider);
      final repository = ref.read(needleRepositoryProvider);

      if (widget.initialNeedle != null) {
        await repository.updateNeedle(needle);
      } else {
        await repository.createNeedle(needle);
      }

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(isKorean ? '저장되었습니다.' : 'Saved successfully.'),
            backgroundColor: C.lv,
          ),
        );
        navigator.pop();
      }
    } catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              isKorean ? '저장에 실패했습니다: $error' : 'Failed to save: $error',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: T.caption.copyWith(
        color: C.mu,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _NeedleSizeSelector extends StatelessWidget {
  final double selectedSize;
  final ValueChanged<double> onSelected;

  const _NeedleSizeSelector({
    required this.selectedSize,
    required this.onSelected,
  });

  static const List<double> _sizes = [
    2.0,
    2.5,
    3.0,
    3.25,
    3.5,
    3.75,
    4.0,
    4.5,
    5.0,
    5.5,
    6.0,
    6.5,
    7.0,
    8.0,
    9.0,
    10.0,
    12.0,
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _sizes.map((size) {
        final isSelected = selectedSize == size;
        final label = size % 1 == 0 ? '${size.toInt()}mm' : '${size}mm';
        return GestureDetector(
          onTap: () => onSelected(size),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? C.lv : C.lvL,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isSelected ? C.lv : C.lv.withValues(alpha: 0.20)),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isSelected ? Colors.white : C.lvD,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SegmentedSelector extends StatelessWidget {
  final List<(String, String)> options;
  final String selected;
  final Color color;
  final ValueChanged<String> onSelected;

  const _SegmentedSelector({
    required this.options,
    required this.selected,
    required this.color,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final isSelected = selected == option.$1;
        return GestureDetector(
          onTap: () => onSelected(option.$1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected ? color : color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isSelected ? color : color.withValues(alpha: 0.20)),
            ),
            child: Text(
              option.$2,
              style: TextStyle(
                fontSize: 13,
                color: isSelected ? Colors.white : color,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  const _QuantityButton({
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: filled ? C.lv : C.lvL,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: filled ? Colors.white : C.lv, size: 20),
      ),
    );
  }
}
