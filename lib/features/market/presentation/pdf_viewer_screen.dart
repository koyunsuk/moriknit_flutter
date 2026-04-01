import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

class PdfViewerScreen extends StatefulWidget {
  final String url;
  final String title;
  const PdfViewerScreen({super.key, required this.url, required this.title});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  String? _localPath;
  bool _loading = true;
  String? _error;
  int _currentPage = 0;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(widget.url));
      final response = await request.close();
      if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
      final bytes = await response.expand((b) => b).toList();
      client.close();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/pattern_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(bytes);
      if (mounted) setState(() { _localPath = file.path; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        title: Text(widget.title, style: T.bodyBold.copyWith(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (_totalPages > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(child: Text('$_currentPage / $_totalPages', style: T.caption.copyWith(color: Colors.white70))),
            ),
        ],
      ),
      body: kIsWeb
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.open_in_new_rounded, color: Colors.white54, size: 48),
                  const SizedBox(height: 16),
                  Text('웹에서는 외부 앱으로 열립니다', style: T.body.copyWith(color: Colors.white70)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('외부 앱으로 열기'),
                    style: ElevatedButton.styleFrom(backgroundColor: C.lv, foregroundColor: Colors.white),
                  ),
                ],
              ),
            )
          : _loading
              ? Center(child: CircularProgressIndicator(color: C.lv))
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.white54, size: 48),
                          const SizedBox(height: 12),
                          Text('파일을 불러올 수 없어요', style: T.body.copyWith(color: Colors.white70)),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () => launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication),
                            child: Text('외부 앱으로 열기', style: TextStyle(color: C.lv)),
                          ),
                        ],
                      ),
                    )
                  : PDFView(
                      filePath: _localPath!,
                      enableSwipe: true,
                      swipeHorizontal: false,
                      autoSpacing: true,
                      pageFling: true,
                      onPageChanged: (page, total) {
                        if (mounted) {
                          setState(() {
                            _currentPage = (page ?? 0) + 1;
                            _totalPages = total ?? 0;
                          });
                        }
                      },
                      onError: (e) {
                        if (mounted) setState(() => _error = '$e');
                      },
                    ),
    );
  }
}
