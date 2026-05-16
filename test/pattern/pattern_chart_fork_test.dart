// 이슈 #629 — PatternChart Fork 필드 호환·라운드트립 단위 테스트.
//
// 검증 포인트:
//  1) 기존(필드 없는) 데이터 → fromJson → 기본값(forkOfId=null, priceWon=0)
//  2) sourcePatternId만 있는 레거시 데이터 → forkOfId 백필
//  3) forkOfId + priceWon 보유 → toJson → fromJson 라운드트립
//  4) priceWon=0 일 때 toJson에서 키 생략 (호환 페이로드 최소화)
//  5) copyWith 로 forkOfId 명시적 null 클리어 가능

import 'package:flutter_test/flutter_test.dart';
import 'package:moriknit_flutter/features/pattern/domain/pattern_chart.dart';

Map<String, dynamic> _baseJson() => {
      'id': 'p1',
      'title': 'Test',
      'rows': 1,
      'cols': 1,
      'mode': 'symbol',
      'grid': [
        {
          'cells': [<String, dynamic>{}],
        }
      ],
    };

void main() {
  group('PatternChart Fork 필드 호환', () {
    test('레거시 데이터(필드 없음) → 기본값', () {
      final chart = PatternChart.fromJson(_baseJson());
      expect(chart.forkOfId, isNull);
      expect(chart.priceWon, 0);
    });

    test('sourcePatternId만 있는 레거시 데이터 → forkOfId 백필', () {
      final json = _baseJson()..['sourcePatternId'] = 'src-id';
      final chart = PatternChart.fromJson(json);
      expect(chart.forkOfId, 'src-id');
      expect(chart.sourcePatternId, 'src-id');
    });

    test('forkOfId + priceWon 라운드트립', () {
      final original = PatternChart(
        id: 'p1',
        title: 'Test',
        rows: 1,
        cols: 1,
        mode: ChartMode.symbol,
        grid: const [
          [CellData()]
        ],
        forkOfId: 'src-id',
        priceWon: 5000,
      );
      final json = original.toJson();
      expect(json['forkOfId'], 'src-id');
      expect(json['priceWon'], 5000);

      final restored = PatternChart.fromJson(json);
      expect(restored.forkOfId, 'src-id');
      expect(restored.priceWon, 5000);
    });

    test('priceWon=0 이면 toJson 키 생략', () {
      final chart = PatternChart(
        id: 'p1',
        title: 'Test',
        rows: 1,
        cols: 1,
        mode: ChartMode.symbol,
        grid: const [
          [CellData()]
        ],
      );
      final json = chart.toJson();
      expect(json.containsKey('priceWon'), isFalse);
      expect(json.containsKey('forkOfId'), isFalse);
    });

    test('copyWith로 forkOfId null 클리어', () {
      final chart = PatternChart(
        id: 'p1',
        title: 'Test',
        rows: 1,
        cols: 1,
        mode: ChartMode.symbol,
        grid: const [
          [CellData()]
        ],
        forkOfId: 'src-id',
      );
      final cleared = chart.copyWith(forkOfId: null);
      expect(cleared.forkOfId, isNull);
      // sourcePatternId는 그대로(독립 필드)
      expect(cleared.sourcePatternId, chart.sourcePatternId);
    });

    test('copyWith로 priceWon 변경', () {
      final chart = PatternChart(
        id: 'p1',
        title: 'Test',
        rows: 1,
        cols: 1,
        mode: ChartMode.symbol,
        grid: const [
          [CellData()]
        ],
      );
      expect(chart.priceWon, 0);
      final priced = chart.copyWith(priceWon: 3000);
      expect(priced.priceWon, 3000);
    });
  });
}
