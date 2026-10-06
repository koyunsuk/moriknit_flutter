// #892 — flutter_blue_plus OOM 수정으로 BLE 임시 비활성화.
// flutter_blue_plus 제거 후 스텁 처리. 향후 메모리 최적화 후 재활성화 예정.

import 'dart:typed_data';

/// D11 라벨 사이즈 (203dpi 기준 픽셀)
enum NiimbotLabelSize {
  s40x12, // 40×12mm → 320×96px
  s40x15, // 40×15mm → 320×120px
  s40x30, // 40×30mm → 320×240px
}

extension NiimbotLabelSizeExt on NiimbotLabelSize {
  int get widthPx => 320;
  int get heightPx {
    switch (this) {
      case NiimbotLabelSize.s40x12: return 96;
      case NiimbotLabelSize.s40x15: return 120;
      case NiimbotLabelSize.s40x30: return 240;
    }
  }
  String get label {
    switch (this) {
      case NiimbotLabelSize.s40x12: return '40×12mm';
      case NiimbotLabelSize.s40x15: return '40×15mm';
      case NiimbotLabelSize.s40x30: return '40×30mm';
    }
  }
}

/// BLE 스캔 결과 스텁
class NiimbotScanResult {
  final String deviceName;
  final String deviceId;
  final int rssi;
  const NiimbotScanResult({
    required this.deviceName,
    required this.deviceId,
    required this.rssi,
  });
}

class NiimbotBleService {
  /// 항상 빈 목록 반환 (BLE 임시 비활성화)
  static Future<List<NiimbotScanResult>> scanNiimbotDevices({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    return [];
  }

  /// 항상 예외 (BLE 임시 비활성화)
  static Future<void> printLabel(
    String deviceId,
    Uint8List pdfBytes, {
    NiimbotLabelSize size = NiimbotLabelSize.s40x30,
  }) async {
    throw Exception('BLE 프린터 기능이 일시 비활성화됐습니다.');
  }
}
