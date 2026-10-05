import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:printing/printing.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../data/label_pdf_generator.dart';
import '../data/niimbot_ble_service.dart';
import '../domain/label_template.dart';

class LabelPreviewScreen extends StatefulWidget {
  final LabelData labelData;

  const LabelPreviewScreen({super.key, required this.labelData});

  @override
  State<LabelPreviewScreen> createState() => _LabelPreviewScreenState();
}

class _LabelPreviewScreenState extends State<LabelPreviewScreen> {
  late LabelData _data;
  final TextEditingController _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _data = widget.labelData;
    _noteCtrl.text = _data.customNote;
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  void _toggleField(String key) {
    setState(() {
      final list = List<String>.from(_data.enabledFields);
      if (list.contains(key)) {
        list.remove(key);
      } else {
        // 원래 순서(fields.keys 순서)를 유지하여 삽입
        final ordered = _data.fields.keys
            .where((k) => k == key || list.contains(k))
            .toList();
        _data = _data.copyWithEnabled(ordered);
        return;
      }
      _data = _data.copyWithEnabled(list);
    });
  }

  Future<void> _print() async {
    await Printing.layoutPdf(
      onLayout: (_) => LabelPdfGenerator.generate(_data),
    );
  }

  Future<void> _savePdf() async {
    final bytes = await LabelPdfGenerator.generate(_data);
    await Printing.sharePdf(bytes: bytes, filename: 'moriknit_label.pdf');
  }

  Future<void> _showNiimbotSheet(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _NiimbotSheet(labelData: _data),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, size: 20, color: C.tx),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('라벨 미리보기', style: T.h3),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          const BgOrbs(),
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              // ── PDF 미리보기 ───────────────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: 240,
                  child: PdfPreview(
                    build: (_) => LabelPdfGenerator.generate(_data),
                    allowPrinting: false,
                    allowSharing: false,
                    canChangePageFormat: false,
                    canChangeOrientation: false,
                    canDebug: false,
                    previewPageMargin: const EdgeInsets.all(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // ── 표시할 정보 선택 ──────────────────────────────────
              MoriBlockShell(
                label: '표시할 정보 선택',
                icon: Icons.checklist_rounded,
                accent: C.lv,
                child: Column(
                  children: _data.fields.entries.map((entry) {
                    final key = entry.key;
                    final value = entry.value;
                    if (value.isEmpty) return const SizedBox.shrink();
                    final label = _data.fieldLabels[key] ?? key;
                    final isEnabled = _data.enabledFields.contains(key);
                    return CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: isEnabled,
                      activeColor: C.lv,
                      title: Row(
                        children: [
                          Text(label,
                              style: T.body.copyWith(
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              value,
                              style: T.caption.copyWith(color: C.mu),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      onChanged: (_) => _toggleField(key),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              // ── 커스텀 메모 ──────────────────────────────────────
              MoriBlockShell(
                label: '추가 메모 (선택)',
                icon: Icons.edit_note_rounded,
                accent: C.mu,
                child: TextField(
                  controller: _noteCtrl,
                  minLines: 2,
                  maxLines: 3,
                  onChanged: (v) {
                    setState(() {
                      _data = _data.copyWithNote(v);
                    });
                  },
                  decoration: InputDecoration(
                    hintText: '라벨에 추가할 메모를 입력하세요',
                    hintStyle: T.caption.copyWith(color: C.mu),
                    border: InputBorder.none,
                    fillColor: Colors.transparent,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _print,
                  icon: const Icon(Icons.print_rounded, size: 18),
                  label: const Text('인쇄'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    backgroundColor: C.lv,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _savePdf,
                  icon: Icon(Icons.picture_as_pdf_outlined,
                      size: 18, color: C.lv),
                  label: Text('PDF 저장', style: TextStyle(color: C.lv)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    side: BorderSide(color: C.lv),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showNiimbotSheet(context),
                  icon: Icon(Icons.label_outline_rounded,
                      size: 18, color: C.og),
                  label: Text('Niimbot', style: TextStyle(color: C.og)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    side: BorderSide(color: C.og),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Niimbot BLE 인쇄 시트 ────────────────────────────────────────────────────
class _NiimbotSheet extends StatefulWidget {
  final LabelData labelData;

  const _NiimbotSheet({required this.labelData});

  @override
  State<_NiimbotSheet> createState() => _NiimbotSheetState();
}

class _NiimbotSheetState extends State<_NiimbotSheet> {
  List<ScanResult> _devices = [];
  bool _isScanning = false;
  bool _isPrinting = false;
  String? _statusMessage;

  Future<void> _scan() async {
    setState(() {
      _isScanning = true;
      _devices = [];
      _statusMessage = null;
    });
    try {
      final results = await NiimbotBleService.scanNiimbotDevices();
      if (mounted) {
        setState(() {
          _devices = results;
          _statusMessage = results.isEmpty ? '근처에 Niimbot 기기가 없어요.' : null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _statusMessage = '스캔 실패: $e');
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _printTo(BluetoothDevice device) async {
    setState(() {
      _isPrinting = true;
      _statusMessage = '인쇄 중...';
    });
    try {
      final pdfBytes = await LabelPdfGenerator.generate(widget.labelData);
      await NiimbotBleService.printLabel(device, pdfBytes);
      if (mounted) setState(() => _statusMessage = '인쇄 완료!');
    } catch (e) {
      if (mounted) setState(() => _statusMessage = '인쇄 실패: $e');
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: C.bd2,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('Niimbot 라벨 프린터', style: T.h3),
            const SizedBox(height: 4),
            Text('블루투스로 근처 Niimbot 기기를 찾아 인쇄합니다.',
                style: T.caption.copyWith(color: C.mu)),
            const SizedBox(height: 16),
            if (_statusMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_statusMessage!,
                    style: T.body.copyWith(color: C.og)),
              ),
            if (_devices.isNotEmpty)
              ..._devices.map((r) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.print_rounded, color: C.lv),
                    title: Text(
                      r.device.platformName.isNotEmpty
                          ? r.device.platformName
                          : r.device.remoteId.toString(),
                      style: T.body,
                    ),
                    subtitle: Text('RSSI: ${r.rssi}',
                        style: T.caption.copyWith(color: C.mu)),
                    trailing: _isPrinting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : TextButton(
                            onPressed: () => _printTo(r.device),
                            child: const Text('인쇄'),
                          ),
                  )),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isScanning ? null : _scan,
                icon: _isScanning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.bluetooth_searching_rounded, size: 18),
                label: Text(_isScanning ? '스캔 중...' : '기기 검색'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: C.lv,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
