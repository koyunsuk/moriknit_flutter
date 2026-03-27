import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';

class PatternEditorScreen extends StatefulWidget {
  const PatternEditorScreen({super.key});

  @override
  State<PatternEditorScreen> createState() => _PatternEditorScreenState();
}

class _PatternEditorScreenState extends State<PatternEditorScreen> {
  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final List<String> _symbols = [];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(backgroundColor: C.bg, elevation: 0, title: Text(isKorean ? '도안 제작' : 'Pattern Editor', style: T.h3)),
      body: Stack(
        children: [
          const BgOrbs(),
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(isKorean ? '도안 정보' : 'Pattern info', style: T.bodyBold), const SizedBox(height: 12), TextField(controller: _titleCtrl, decoration: InputDecoration(labelText: isKorean ? '도안 이름' : 'Pattern title')), const SizedBox(height: 10), TextField(controller: _notesCtrl, maxLines: 4, decoration: InputDecoration(labelText: isKorean ? '메모' : 'Notes'))])),
              const SizedBox(height: 14),
              GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(isKorean ? '기호 빠른 추가' : 'Quick symbols', style: T.bodyBold), const SizedBox(height: 12), Wrap(spacing: 10, runSpacing: 10, children: [for (final symbol in ['K', 'P', 'YO', 'K2tog', 'SSK', 'M1']) _SymbolChip(symbol: symbol, onTap: () => setState(() => _symbols.add(symbol)))]), const SizedBox(height: 14), Text(isKorean ? '현재 순서' : 'Current sequence', style: T.captionBold), const SizedBox(height: 8), Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.86), borderRadius: BorderRadius.circular(14), border: Border.all(color: C.bd)), child: Text(_symbols.isEmpty ? (isKorean ? '아직 추가된 기호가 없어요.' : 'No symbols added yet.') : _symbols.join('  ·  '), style: T.body))])),
              const SizedBox(height: 14),
              GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(isKorean ? '활용 팁' : 'Usage notes', style: T.bodyBold), const SizedBox(height: 10), Text(isKorean ? '간단한 반복 패턴, 메모, 기호 조합을 빠르게 적어두는 v0.9용 편집기입니다.' : 'This is a lightweight v0.9 editor for repeats, notes, and symbol combinations.', style: T.body.copyWith(color: C.tx2))])),
            ],
          ),
        ],
      ),
    );
  }
}

class _SymbolChip extends StatelessWidget {
  final String symbol;
  final VoidCallback onTap;
  const _SymbolChip({required this.symbol, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(99), child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(color: C.lvL, borderRadius: BorderRadius.circular(99), border: Border.all(color: C.lv.withValues(alpha: 0.22))), child: Text(symbol, style: T.bodyBold.copyWith(color: C.lvD))));
  }
}
