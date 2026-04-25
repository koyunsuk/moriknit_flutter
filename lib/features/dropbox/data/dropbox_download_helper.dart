import 'dart:typed_data';

/// Stub — 조건부 import 디폴트.
/// 실제 구현은 dropbox_download_helper_io.dart / dropbox_download_helper_web.dart.
void triggerWebDownload(Uint8List bytes, String fileName, String mimeType) {
  throw UnsupportedError('triggerWebDownload는 웹에서만 사용해요.');
}
