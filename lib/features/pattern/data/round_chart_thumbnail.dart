// lib/features/pattern/data/round_chart_thumbnail.dart
//
// 이슈 #665 Phase 5 — 원형 도안 썸네일 생성기.
//
// 목적: 도안 라이브러리 카드용 256×256 PNG를 RoundChartPainter로 오프스크린 렌더링.
// 사각 도안의 imageUrl과 동일한 슬롯에 base64 데이터 URL 또는 메모리 캐시로 전달.
//
// 저장 전략 (1차 — 단순):
//   - PictureRecorder + Canvas로 in-memory 렌더 → ui.Image → toByteData(png)
//   - 결과 bytes를 호출자가 base64 문자열로 변환해 imageUrl에 보관 가능
//   - 메모리 캐시(LRU)로 재사용 — patternId → bytes
//
// 저장 전략 (2차 — 영구):
//   - generateAndUpload()로 Firebase Storage 업로드 후 다운로드 URL 반환
//   - 영구·공유용. 호출자가 PatternRepository.save 시점에 imageUrl 채움
//
// 호출 시점:
//   - PatternRepository.save에서 chartType이 round*면 자동 생성 (메모리)
//   - 사용자 명시 요청 시 generateAndUpload (Firebase Storage 영구 보관)

import 'dart:async';
import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../domain/round_chart.dart';
import '../presentation/widgets/round_chart_painter.dart';

/// 원형 도안 썸네일 메모리 캐시 (LRU 단순 구현).
/// 키: patternId, 값: PNG bytes.
class RoundThumbnailCache {
  static const int _maxEntries = 64;
  final Map<String, Uint8List> _cache = <String, Uint8List>{};

  Uint8List? get(String patternId) {
    final v = _cache.remove(patternId);
    if (v != null) {
      // 최근 접근 순서 유지 (Map 삽입 순서가 곧 LRU 순서).
      _cache[patternId] = v;
    }
    return v;
  }

  void put(String patternId, Uint8List bytes) {
    _cache.remove(patternId);
    _cache[patternId] = bytes;
    if (_cache.length > _maxEntries) {
      // 가장 오래된 항목 제거.
      final firstKey = _cache.keys.first;
      _cache.remove(firstKey);
    }
  }

  void invalidate(String patternId) => _cache.remove(patternId);

  void clear() => _cache.clear();
}

/// 모듈 단위 글로벌 캐시 인스턴스.
final RoundThumbnailCache roundThumbnailCache = RoundThumbnailCache();

/// 원형 도안 PNG 썸네일 생성.
///
/// [chart]: 렌더링할 RoundChart.
/// [size]: 출력 픽셀 크기 (정사각형 권장). 기본 256×256.
/// [background]: 배경색. 기본 흰색.
/// [showGuides]: 가이드(점선 동심원) 표시 여부. 썸네일은 false 권장.
/// [showRoundLabels]: 라운드 라벨 표시 여부. 썸네일은 false 권장.
///
/// 반환: PNG 바이트. 실패 시 null.
Future<Uint8List?> generateRoundThumbnail(
  RoundChart chart, {
  Size size = const Size(256, 256),
  Color background = Colors.white,
  bool showGuides = false,
  bool showRoundLabels = false,
}) async {
  try {
    // PictureRecorder로 오프스크린 캔버스 준비.
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, size.width, size.height),
    );

    // 배경 페인트.
    final bgPaint = Paint()..color = background;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      bgPaint,
    );

    // 원형 도안 페인터로 그리기.
    // 썸네일 단계에서는 SVG 심볼 캐시가 미초기화 상태일 수 있어
    // null 반환 콜백을 사용 (심볼은 비표시, 색상·구조만 노출).
    final painter = RoundChartPainter(
      chart: chart,
      symbolPicture: (_) => null,
      showGuides: showGuides,
      showRoundLabels: showRoundLabels,
    );
    painter.paint(canvas, size);

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      size.width.toInt(),
      size.height.toInt(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    image.dispose();

    if (byteData == null) return null;
    return byteData.buffer.asUint8List();
  } catch (e, st) {
    debugPrint('[generateRoundThumbnail] FAILED: $e\n$st');
    return null;
  }
}

/// 원형 도안 썸네일을 생성한 뒤 Firebase Storage에 업로드 → 다운로드 URL 반환.
///
/// 저장 경로: `users/{uid}/patterns/round_thumbnails/{patternId}.png`
/// 동일 patternId는 덮어쓰기 (멱등).
///
/// 실패 시 null 반환 (호출자가 fallback 가능).
Future<String?> generateAndUploadRoundThumbnail({
  required String patternId,
  required RoundChart chart,
  Size size = const Size(256, 256),
}) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null || uid.isEmpty) return null;
  if (patternId.isEmpty) return null;

  try {
    final bytes = await generateRoundThumbnail(chart, size: size);
    if (bytes == null || bytes.isEmpty) return null;

    // 메모리 캐시 갱신.
    roundThumbnailCache.put(patternId, bytes);

    final ref = FirebaseStorage.instance.ref().child(
          'users/$uid/patterns/round_thumbnails/$patternId.png',
        );
    await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/png'),
    );
    return await ref.getDownloadURL();
  } catch (e, st) {
    debugPrint('[generateAndUploadRoundThumbnail] FAILED: $e\n$st');
    return null;
  }
}
