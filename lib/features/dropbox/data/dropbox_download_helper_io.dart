import 'dart:typed_data';

/// 모바일/데스크톱: 사용하지 않음 (share_plus가 처리).
void triggerWebDownload(Uint8List bytes, String fileName, String mimeType) {
  // no-op (모바일에서는 호출되지 않음)
}
