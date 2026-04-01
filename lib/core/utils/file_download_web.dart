// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

Future<void> downloadBytes({
  required Uint8List bytes,
  required String mimeType,
  required String fileName,
}) async {
  final dataUri =
      'data:$mimeType;base64,${base64Encode(bytes)}';
  final anchor = html.AnchorElement(href: dataUri)
    ..download = fileName
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
}
