// Android: AndroidManifest.xml에 BLUETOOTH_SCAN, BLUETOOTH_CONNECT 권한 필요
//   <uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
//   <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
// iOS: Info.plist에 NSBluetoothAlwaysUsageDescription 필요
//   <key>NSBluetoothAlwaysUsageDescription</key>
//   <string>Niimbot 라벨 프린터 연결에 블루투스가 필요합니다.</string>

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class NiimbotBleService {
  static const _niimbotPrefixes = ['D11', 'B21', 'D110', 'B3S', 'B1'];

  /// 근처 Niimbot 기기 스캔 (이름 접두사로 필터링)
  static Future<List<ScanResult>> scanNiimbotDevices({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    await FlutterBluePlus.startScan(timeout: timeout);
    await Future.delayed(timeout);
    final results = await FlutterBluePlus.scanResults.first;
    return results.where((r) {
      final name = r.device.platformName.toUpperCase();
      return _niimbotPrefixes.any((p) => name.startsWith(p));
    }).toList();
  }

  /// 이미지 바이트를 Niimbot BLE 프로토콜로 전송
  /// [device]: 연결할 BluetoothDevice
  /// [imageBytes]: 출력할 이미지 raw bytes (PNG/BMP 등)
  static Future<void> printLabel(
    BluetoothDevice device,
    Uint8List imageBytes,
  ) async {
    await device.connect(timeout: const Duration(seconds: 10));

    try {
      final services = await device.discoverServices();

      // Niimbot BLE service UUID: 0000ff01-0000-1000-8000-00805f9b34fb (D11 기준)
      final targetService = services.firstWhere(
        (s) => s.serviceUuid.toString().toLowerCase().contains('ff01'),
        orElse: () => services.first,
      );

      final characteristic = targetService.characteristics.firstWhere(
        (c) => c.properties.write || c.properties.writeWithoutResponse,
      );

      // 이미지를 청크로 분할 전송
      const chunkSize = 200;
      for (var i = 0; i < imageBytes.length; i += chunkSize) {
        final end = (i + chunkSize < imageBytes.length)
            ? i + chunkSize
            : imageBytes.length;
        await characteristic.write(
          imageBytes.sublist(i, end),
          withoutResponse: true,
        );
        await Future.delayed(const Duration(milliseconds: 10));
      }
    } finally {
      await device.disconnect();
    }
  }
}
