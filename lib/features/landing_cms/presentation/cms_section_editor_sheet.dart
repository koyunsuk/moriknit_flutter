// 이슈 — 랜딩 CMS: 섹션 타입별 편집 시트.
//
// hero / featureGrid / faq / pricing / cta / markdown / imageGallery / testimonial / custom

import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/landing_page.dart';

/// 섹션 편집 결과 ('저장' 누른 경우만 LandingSection 반환).
Future<LandingSection?> showCmsSectionEditorSheet(
  BuildContext context, {
  required LandingSection initial,
}) async {
  return await showModalBottomSheet<LandingSection>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CmsSectionEditorSheet(initial: initial),
  );
}

class _CmsSectionEditorSheet extends StatefulWidget {
  final LandingSection initial;
  const _CmsSectionEditorSheet({required this.initial});

  @override
  State<_CmsSectionEditorSheet> createState() => _CmsSectionEditorSheetState();
}

class _CmsSectionEditorSheetState extends State<_CmsSectionEditorSheet> {
  late SectionType _type;
  late Map<String, dynamic> _content;

  // 공용 컨트롤러들 (타입별로 골라 씀)
  final _titleCtrl = TextEditingController();
  final _subtitleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _imageUrlCtrl = TextEditingController();
  final _ctaTextCtrl = TextEditingController();
  final _ctaLinkCtrl = TextEditingController();
  final _captionCtrl = TextEditingController();
  // 컬렉션(items) — JSON 텍스트 편집
  final _itemsJsonCtrl = TextEditingController();
  // 갤러리 — 줄바꿈 구분 URL
  final _imagesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _type = widget.initial.type;
    _content = Map<String, dynamic>.from(widget.initial.content);
    _loadFieldsFromContent();
  }

  void _loadFieldsFromContent() {
    _titleCtrl.text = (_content['title'] as String?) ?? '';
    _subtitleCtrl.text = (_content['subtitle'] as String?) ?? '';
    _bodyCtrl.text = (_content['body'] as String?) ?? '';
    _imageUrlCtrl.text = (_content['imageUrl'] as String?) ?? '';
    _ctaTextCtrl.text = (_content['ctaText'] as String?) ?? '';
    _ctaLinkCtrl.text = (_content['ctaLink'] as String?) ?? '';
    _captionCtrl.text = (_content['caption'] as String?) ?? '';

    final items = _content['items'];
    if (items is List) {
      try {
        _itemsJsonCtrl.text =
            const JsonEncoder.withIndent('  ').convert(items);
      } catch (_) {
        _itemsJsonCtrl.text = '[]';
      }
    } else {
      _itemsJsonCtrl.text = '[]';
    }

    final images = _content['images'];
    if (images is List) {
      _imagesCtrl.text = images.map((e) => e?.toString() ?? '').join('\n');
    } else {
      _imagesCtrl.text = '';
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subtitleCtrl.dispose();
    _bodyCtrl.dispose();
    _imageUrlCtrl.dispose();
    _ctaTextCtrl.dispose();
    _ctaLinkCtrl.dispose();
    _captionCtrl.dispose();
    _itemsJsonCtrl.dispose();
    _imagesCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _collectContent() {
    final out = <String, dynamic>{};
    void putString(String key, TextEditingController c) {
      final v = c.text.trim();
      if (v.isNotEmpty) out[key] = v;
    }

    switch (_type) {
      case SectionType.hero:
        putString('title', _titleCtrl);
        putString('subtitle', _subtitleCtrl);
        putString('imageUrl', _imageUrlCtrl);
        putString('ctaText', _ctaTextCtrl);
        putString('ctaLink', _ctaLinkCtrl);
        break;
      case SectionType.featureGrid:
        putString('title', _titleCtrl);
        putString('subtitle', _subtitleCtrl);
        out['items'] = _parseItemsJson();
        break;
      case SectionType.faq:
        putString('title', _titleCtrl);
        out['items'] = _parseItemsJson();
        break;
      case SectionType.pricing:
        putString('title', _titleCtrl);
        putString('subtitle', _subtitleCtrl);
        out['items'] = _parseItemsJson();
        break;
      case SectionType.cta:
        putString('title', _titleCtrl);
        putString('subtitle', _subtitleCtrl);
        putString('ctaText', _ctaTextCtrl);
        putString('ctaLink', _ctaLinkCtrl);
        break;
      case SectionType.markdown:
        putString('title', _titleCtrl);
        putString('body', _bodyCtrl);
        break;
      case SectionType.imageGallery:
        putString('title', _titleCtrl);
        putString('caption', _captionCtrl);
        out['images'] = _imagesCtrl.text
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        break;
      case SectionType.testimonial:
        putString('title', _titleCtrl);
        out['items'] = _parseItemsJson();
        break;
      case SectionType.custom:
        // 원본 content 유지 + 표시 가능한 필드만 덮어쓰기
        out.addAll(_content);
        putString('title', _titleCtrl);
        putString('body', _bodyCtrl);
        break;
    }
    return out;
  }

  List<Map<String, dynamic>> _parseItemsJson() {
    try {
      final decoded = json.decode(_itemsJsonCtrl.text.trim());
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
      }
    } catch (_) {
      // 파싱 실패 시 빈 리스트 (호출자에서 추가 검증 가능)
    }
    return const <Map<String, dynamic>>[];
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFFFFFFFF),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Header(
                onClose: () => Navigator.pop(context),
                onSave: () {
                  final updated = widget.initial.copyWith(
                    type: _type,
                    content: _collectContent(),
                  );
                  Navigator.pop(context, updated);
                },
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _typeDropdown(),
                      const SizedBox(height: 16),
                      ..._buildTypeFields(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeDropdown() {
    return DropdownButtonFormField<SectionType>(
      initialValue: _type,
      decoration: InputDecoration(
        labelText: '섹션 타입',
        filled: true,
        fillColor: C.gx,
      ),
      items: SectionType.values
          .map(
            (t) => DropdownMenuItem<SectionType>(
              value: t,
              child: Text('${t.label} (${t.raw})'),
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) setState(() => _type = v);
      },
    );
  }

  List<Widget> _buildTypeFields() {
    switch (_type) {
      case SectionType.hero:
        return [
          _tf(_titleCtrl, label: '타이틀', hint: 'Hero 제목'),
          _tf(_subtitleCtrl, label: '서브타이틀', hint: '부제'),
          _tf(_imageUrlCtrl, label: '이미지 URL'),
          _tf(_ctaTextCtrl, label: 'CTA 버튼 텍스트'),
          _tf(_ctaLinkCtrl, label: 'CTA 링크 URL'),
        ];
      case SectionType.featureGrid:
        return [
          _tf(_titleCtrl, label: '타이틀'),
          _tf(_subtitleCtrl, label: '서브타이틀'),
          _itemsHint('items 형식: [{"title":..., "desc":..., "icon":..., "image":...}, ...]'),
          _itemsField(),
        ];
      case SectionType.faq:
        return [
          _tf(_titleCtrl, label: '타이틀'),
          _itemsHint('items 형식: [{"question":..., "answer":...}, ...]'),
          _itemsField(),
        ];
      case SectionType.pricing:
        return [
          _tf(_titleCtrl, label: '타이틀'),
          _tf(_subtitleCtrl, label: '서브타이틀'),
          _itemsHint('items 형식: [{"name":..., "price":..., "features":[...]}, ...]'),
          _itemsField(),
        ];
      case SectionType.cta:
        return [
          _tf(_titleCtrl, label: '타이틀'),
          _tf(_subtitleCtrl, label: '서브타이틀'),
          _tf(_ctaTextCtrl, label: '버튼 텍스트'),
          _tf(_ctaLinkCtrl, label: '버튼 링크 URL'),
        ];
      case SectionType.markdown:
        return [
          _tf(_titleCtrl, label: '타이틀'),
          _tf(_bodyCtrl, label: '본문 (Markdown)', maxLines: 14),
        ];
      case SectionType.imageGallery:
        return [
          _tf(_titleCtrl, label: '타이틀'),
          _tf(_captionCtrl, label: '캡션'),
          _itemsHint('이미지 URL을 줄바꿈으로 구분해 입력하세요.'),
          _tf(_imagesCtrl, label: '이미지 URL 목록', maxLines: 8),
        ];
      case SectionType.testimonial:
        return [
          _tf(_titleCtrl, label: '타이틀'),
          _itemsHint('items 형식: [{"name":..., "role":..., "quote":..., "avatar":...}, ...]'),
          _itemsField(),
        ];
      case SectionType.custom:
        return [
          _tf(_titleCtrl, label: '타이틀'),
          _tf(_bodyCtrl, label: '본문(자유)', maxLines: 10),
          const SizedBox(height: 8),
          Text(
            '※ custom 섹션은 랜더링이 보장되지 않으며, 알 수 없는 타입은 fallback 위젯이 표시됩니다.',
            style: T.caption.copyWith(color: C.mu),
          ),
        ];
    }
  }

  Widget _tf(
    TextEditingController c, {
    required String label,
    String? hint,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: C.gx,
        ),
      ),
    );
  }

  Widget _itemsHint(String msg) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Text(msg, style: T.caption.copyWith(color: C.mu)),
    );
  }

  Widget _itemsField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: _itemsJsonCtrl,
        maxLines: 12,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        decoration: InputDecoration(
          labelText: 'items (JSON 배열)',
          filled: true,
          fillColor: C.gx,
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onSave;
  const _Header({required this.onClose, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
      child: Row(
        children: [
          IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
          const SizedBox(width: 4),
          Text('섹션 편집', style: T.h3),
          const Spacer(),
          ElevatedButton(
            onPressed: onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: C.lv,
              foregroundColor: Colors.white,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }
}
