import 'package:flutter_test/flutter_test.dart';
import 'package:reksatani_app/features/transaksi/controllers/kasbon_controller.dart';
import 'package:reksatani_app/models/hive/petani_hive_model.dart';
import 'dart:math';

void main() {
  group('KasbonController State Management Stress Testing', () {
    late KasbonController controller;
    late PetaniHiveModel mockPetani;
    final random = Random();

    setUp(() {
      controller = KasbonController();
      mockPetani = PetaniHiveModel(
        id: 'petani-stress',
        namaPetani: 'Petani Stress Test',
        desa: 'Lab-1',
        pengepulId: 'agen-1',
        sisaHutangKasbon: 1000000,
        waktuDibuat: DateTime.now(),
      );
      controller.setSelectedPetani(mockPetani);
    });

    test('ST-005: Hyperactive Input Update - 10.000 Rapid Updates', () async {
      print('Memulai ST-005: Simulasi 10.000 perubahan input pada KasbonController...');
      
      const int iterations = 10000;
      final stopwatch = Stopwatch()..start();

      int notifyCount = 0;
      controller.addListener(() {
        notifyCount++;
      });

      double expectedTotal = 0;
      double lastBerat = 0;
      double lastHarga = 0;

      for (int i = 0; i < iterations; i++) {
        lastBerat = random.nextDouble() * 100;
        lastHarga = (random.nextInt(10) + 1) * 1000.0;

        controller.setBerat(lastBerat);
        controller.setHargaPerKg(lastHarga);
        
        expectedTotal = lastBerat * lastHarga;
      }

      stopwatch.stop();
      final duration = stopwatch.elapsedMilliseconds;

      print('Hasil Stress Test State Management:');
      print('   - Total Iterasi (Updates): $iterations');
      print('   - Total Notifikasi UI: $notifyCount');
      print('   - Total Durasi: ${duration}ms');
      print('   - Rata-rata per update: ${(duration / iterations).toStringAsFixed(4)}ms');
      print('   - Final Berat: ${controller.berat.toStringAsFixed(2)}');
      print('   - Final Harga: ${controller.hargaPerKg.toStringAsFixed(0)}');
      print('   - Final Total Bayar: ${controller.totalBayar.toStringAsFixed(0)}');

      expect(duration, lessThan(1000), 
        reason: '10.000 update state harus selesai di bawah 1 detik.');

      expect(controller.totalBayar, closeTo(expectedTotal, 0.001), 
        reason: 'Hasil kalkulasi akhir harus presisi sesuai input terakhir.');

      expect(notifyCount, iterations * 2, 
        reason: 'notifyListeners() harus dipanggil setiap kali state berubah.');
    });
  });
}
