import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:reksatani_app/features/transaksi/config/grading_config.dart';
import 'dart:math';

void main() {
  late Directory tempDir;
  final random = Random();

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('config_logging_stress');
    Hive.init(tempDir.path);
    await GradingConfig.init();
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('GradingConfig Stress Testing', () {
    test('ST-004: Massive Config Logging - 5.000 Decision Evaluations', () async {
      print('Memulai ST-004: Mengevaluasi 5.000 keputusan AI secara cepat...');
      
      const int iterations = 5000;
      final stopwatch = Stopwatch()..start();

      for (int i = 0; i < iterations; i++) {
        final grades = ['A', 'B', 'C'];
        final grade = grades[random.nextInt(3)];
        final confidence = random.nextDouble();

        GradingConfig.shouldAccept(grade, confidence);
      }

      stopwatch.stop();
      final duration = stopwatch.elapsedMilliseconds;

      final logs = GradingConfig.getAuditLogs();

      print('Hasil Stress Test Config Logging:');
      print('   - Total Iterasi: $iterations');
      print('   - Total Durasi: ${duration}ms');
      print('   - Rata-rata per evaluasi: ${(duration / iterations).toStringAsFixed(4)}ms');
      print('   - Jumlah Log di Hive (Rotation Check): ${logs.length}');

      expect(duration, lessThan(1000), 
        reason: '5.000 evaluasi harus selesai di bawah 1 detik.');

      expect(logs.length, lessThanOrEqualTo(100), 
        reason: 'Mekanisme rotasi log harus membatasi maksimal 100 entri terakhir.');
    });
  });
}
