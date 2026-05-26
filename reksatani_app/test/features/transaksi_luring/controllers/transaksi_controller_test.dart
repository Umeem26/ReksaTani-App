import 'package:flutter_test/flutter_test.dart';
import 'package:reksatani_app/features/transaksi_luring/controllers/transaksi_controller.dart';
import 'package:reksatani_app/models/hive/komoditas_hive_model.dart';

void main() {
  late TransaksiController controller;

  setUp(() {
    controller = TransaksiController();
  });

  group('TransaksiController Unit Tests', () {
    test('getTotalBayar calculates correct total (Positive)', () {
      expect(controller.getTotalBayar("10", "50000"), 500000.0);
      expect(controller.getTotalBayar("2.5", "10000"), 25000.0);
    });

    test('getTotalBayar handles invalid inputs gracefully (Negative)', () {
      expect(controller.getTotalBayar("", ""), 0.0);
      expect(controller.getTotalBayar("abc", "50000"), 0.0);
      expect(controller.getTotalBayar("10", "xyz"), 0.0);
    });

    test('getHargaMaksGrade returns correct max price (Positive)', () {
      final mockKomoditas = KomoditasHiveModel(
        id: '1',
        namaKomoditas: 'Padi',
        unitSatuan: 'kg',
        gradeKualitas: [
          {'grade': 'A', 'harga_maks': 10000.0},
          {'grade': 'B', 'harga_maks': 8000.0},
        ],
        diperbaruiOleh: 'admin',
        waktuPembaruan: DateTime.now(),
      );

      expect(controller.getHargaMaksGrade(mockKomoditas, 'A'), 10000.0);
      expect(controller.getHargaMaksGrade(mockKomoditas, 'B'), 8000.0);
      expect(controller.getHargaMaksGrade(mockKomoditas, 'C'), 0.0);
    });

    test('isHargaMelebihi returns boolean flag correctly (Edge Case)', () {
      final mockKomoditas = KomoditasHiveModel(
        id: '1',
        namaKomoditas: 'Jagung',
        unitSatuan: 'kg',
        gradeKualitas: [
          {'grade': 'A', 'harga_maks': 5000.0},
        ],
        diperbaruiOleh: 'admin',
        waktuPembaruan: DateTime.now(),
      );

      // harga pas (tidak melebihi)
      expect(controller.isHargaMelebihi(mockKomoditas, 'A', '5000'), false);
      // harga di bawah (tidak melebihi)
      expect(controller.isHargaMelebihi(mockKomoditas, 'A', '4000'), false);
      // harga di atas (melebihi)
      expect(controller.isHargaMelebihi(mockKomoditas, 'A', '5001'), true);
      // grade null
      expect(controller.isHargaMelebihi(mockKomoditas, null, '6000'), false);
    });
  });
}
