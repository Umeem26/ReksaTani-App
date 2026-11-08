import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:reksatani_app/features/pcd_scanner/services/commodity_mapper.dart';
import 'package:reksatani_app/features/pcd_scanner/services/grading_ml_service.dart';
import 'package:reksatani_app/features/transaksi_luring/controllers/transaksi_controller.dart';

void main() {
  final svc = GradingMlService(isTestMode: true);

  group('decideCommodity (shared live/still decision)', () {
    test('class 0 bukan_komoditas wins -> notCommodity, no grade', () {
      final r = svc.decideCommodity([0.6, 0.2, 0.1, 0.1], 0.9);
      expect(r.status, ScanStatus.notCommodity);
      expect(r.commodity, isNull);
      expect(r.grade, isNull);
      expect(r.isAccepted, isFalse);
    });

    test('router max below threshold -> notCommodity', () {
      expect(svc.decideCommodity([0.24, 0.24, 0.28, 0.24], 0.9).status, ScanStatus.ok); // 0.28 >= 0.25
      // Unnormalised scores below the 0.25 router threshold.
      expect(svc.decideCommodity([0.1, 0.2, 0.1, 0.1], 0.9).status, ScanStatus.notCommodity);
    });

    test('empty frame (foreground < 1%) -> notCommodity', () {
      final r = svc.decideCommodity([0.0, 0.9, 0.05, 0.05], 0.005);
      expect(r.status, ScanStatus.notCommodity);
    });

    test('confident commodity -> ok with router confidence', () {
      final r = svc.decideCommodity([0.05, 0.05, 0.1, 0.8], 0.6);
      expect(r.status, ScanStatus.ok);
      expect(r.commodity, 'kopi');
      expect(r.routerConfidence, closeTo(0.8, 1e-9));
      expect(r.grade, isNull, reason: 'router-only decision never invents a grade');
    });

    test('error result has no grade and is not accepted', () {
      final r = ScanResult.error('boom');
      expect(r.status, ScanStatus.error);
      expect(r.grade, isNull);
      expect(r.isAccepted, isFalse);
      expect(r.toMap()['grade'], isNull);
    });

    test('foregroundRatioOf counts non-white pixels on [0,255] input', () {
      final t = Float32List(12)..fillRange(0, 12, 255.0);
      t[0] = 10; // pixel 0 is foreground
      expect(GradingMlService.foregroundRatioOf(t), closeTo(0.25, 1e-9));
    });
  });

  group('CommodityMapper', () {
    const names = ['Gabah', 'Kopi Robusta', 'Sawit'];
    String id(String s) => s;

    test('ML labels map by case-insensitive contains', () {
      expect(CommodityMapper.match(names, id, 'gabah'), 'Gabah');
      expect(CommodityMapper.match(names, id, 'kopi'), 'Kopi Robusta');
      expect(CommodityMapper.match(names, id, 'kelapa_sawit'), 'Sawit');
      expect(CommodityMapper.match(names, id, 'bukan_komoditas'), isNull);
      expect(CommodityMapper.match(names, id, null), isNull);
    });

    test('falls back to OCR commodity when ML label has no match', () {
      expect(
        CommodityMapper.matchWithFallback(['Gabah', 'Sawit'], id, mlLabel: 'kopi', ocrLabel: 'sawit'),
        'Sawit',
      );
      expect(
        CommodityMapper.matchWithFallback(names, id, mlLabel: 'kopi', ocrLabel: 'sawit'),
        'Kopi Robusta',
      );
    });
  });

  group('TransaksiController.parseAngka', () {
    test('accepts comma and dot decimals', () {
      expect(TransaksiController.parseAngka('12,5'), 12.5);
      expect(TransaksiController.parseAngka('12.5'), 12.5);
      expect(TransaksiController.parseAngka('150'), 150);
      expect(TransaksiController.parseAngka(''), isNull);
      expect(TransaksiController.parseAngka('.'), isNull);
    });
  });
}
