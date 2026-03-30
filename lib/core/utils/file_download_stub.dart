import 'dart:typed_data';

Future<void> downloadBytes({
  required Uint8List bytes,
  required String mimeType,
  required String fileName,
}) async {
  throw UnsupportedError('Web download is only supported on web builds.');
}
