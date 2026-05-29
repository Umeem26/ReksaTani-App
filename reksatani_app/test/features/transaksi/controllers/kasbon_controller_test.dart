import 'package:flutter_test/flutter_test.dart';
import 'package:reksatani_app/features/transaksi/controllers/kasbon_controller.dart';
import 'package:reksatani_app/models/hive/petani_hive_model.dart';

void main() {
  group('KasbonController Unit Tests', () {
    late KasbonController controller;
    late PetaniHiveModel mockPetani;

    setUp(() {
      controller = KasbonController();
      mockPetani = PetaniHiveModel(
        id: 'petani-1',
        namaPetani: 'Pak Budi',
        desa: 'Sukamaju',
        pengepulId: 'agen-1',
        sisaHutangKasbon: 500000,
        waktuDibuat: DateTime.now(),
      );
    });

    test('Initial values should be default', () {
      expect(controller.berat, 0.0);
      expect(controller.hargaPerKg, 0.0);
      expect(controller.totalBayar, 0.0);
      expect(controller.selectedPetani, isNull);
    });

    test('Calculation of total bayar should be correct', () {
      controller.setBerat(10.0);
      controller.setHargaPerKg(15000.0);
      expect(controller.totalBayar, 150000.0);
    });

    test('Kasbon deduction calculation should be correct', () {
      controller.setSelectedPetani(mockPetani);
      controller.setBerat(10.0);
      controller.setHargaPerKg(10000.0);
      
      expect(controller.sisaKasbonPetani, 400000.0);
    });

    test('Kasbon should not be negative', () {
      controller.setSelectedPetani(mockPetani);
      controller.setBerat(100.0);
      controller.setHargaPerKg(10000.0);
      
      expect(controller.sisaKasbonPetani, 0.0);
    });

    test('Validation should fail if total > uang jalan', () {
      controller.setSelectedPetani(mockPetani);
      controller.setBerat(10.0);
      controller.setHargaPerKg(1000.0);
      
      expect(controller.isValid, isFalse);
      expect(controller.error, contains("Uang jalan agen tidak mencukupi"));
    });

    test('Auto-fill injection should update state', () {
      controller.injectAutoFillData(
        imagePath: 'path/to/img.jpg',
        berat: 12.5,
        hargaPerKg: 12000.0,
        grade: 'A',
      );

      expect(controller.berat, 12.5);
      expect(controller.hargaPerKg, 12000.0);
      expect(controller.selectedGrade, 'A');
      expect(controller.imagePath, 'path/to/img.jpg');
    });
  });
}
