import 'package:flutter_test/flutter_test.dart';
import 'package:reksatani_app/features/transaksi/services/isolate_processor.dart';
import 'dart:async';

void main() {
  group('Isolate Concurrency Stress Testing', () {
    late IsolateProcessor processor;

    setUp(() {
      processor = IsolateProcessor();
    });

    test('ST-003: Rapid Fire Isolate - 50 Concurrent Processing Requests', () async {
      print('Memulai ST-003: Menjalankan 50 Isolate secara paralel...');
      
      const int totalRequests = 50;
      final List<Future<Map<String, dynamic>>> futures = [];
      final stopwatch = Stopwatch()..start();

      for (int i = 0; i < totalRequests; i++) {
        futures.add(
          processor.processImageInIsolate(
            'stress_test_image_$i.jpg',
            timeout: const Duration(seconds: 10),
          ).catchError((e) {
            print('Request $i gagal: $e');
            return <String, dynamic>{'status': 'error', 'error': e.toString()};
          }),
        );
      }

      final results = await Future.wait(futures);
      
      stopwatch.stop();
      final duration = stopwatch.elapsedMilliseconds;
      
      int successCount = results.where((r) => r['status'] == 'success').length;
      int errorCount = results.where((r) => r['status'] == 'error').length;

      print('Hasil Stress Test Isolate:');
      print('   - Total Request: $totalRequests');
      print('   - Berhasil: $successCount');
      print('   - Gagal/Timeout: $errorCount');
      print('   - Total Durasi: ${duration}ms');
      print('   - Rata-rata per Isolate: ${(duration / totalRequests).toStringAsFixed(2)}ms');

      expect(successCount, greaterThanOrEqualTo(totalRequests * 0.9), 
        reason: 'Mayoritas request isolate harus berhasil meskipun dijalankan paralel.');
      
      expect(duration, lessThan(15000), 
        reason: '50 Isolate (dengan delay simulasi 800ms) harusnya selesai di bawah 15 detik jika paralel benar.');
    });
  });
}
