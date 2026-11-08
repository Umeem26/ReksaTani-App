import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:reksatani_app/features/pcd_scanner/services/grading_ml_service.dart';

void main() {
  // Hubungkan binding widget agar Flutter Test Services dapat diakses jika diperlukan
  TestWidgetsFlutterBinding.ensureInitialized();

  late GradingMlService gradingService;
  late Directory tempDir;

  setUp(() async {
    // Inisialisasi service dalam mode tes agar tes berjalan lancar di host OS tanpa library native TFLite
    gradingService = GradingMlService(isTestMode: true);
    tempDir = await Directory.systemTemp.createTemp('grading_ml_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
    gradingService.dispose();
  });

  /// Helper untuk membuat file gambar dummy dengan warna RGB tertentu untuk pengujian preprocessing & inferensi
  File createTestImage(String name, int r, int g, int b) {
    final image = img.Image(width: 100, height: 100);
    img.fill(image, color: img.ColorRgb8(r, g, b));

    final file = File('${tempDir.path}/$name');
    file.writeAsBytesSync(img.encodeJpg(image));
    return file;
  }

  group('Grading ML Service Tests', () {
    test('1. Test Model Loading & Caching', () async {
      expect(gradingService.isModelLoaded, isFalse, reason: 'Model seharusnya belum dimuat pada startup awal');
      
      // Load model pertama kali
      await gradingService.loadModel();
      expect(gradingService.isModelLoaded, isTrue, reason: 'Model harus terdaftar sebagai loaded');

      // Load model kedua kali (harus mengembalikan secara instan karena caching)
      final stopwatch = Stopwatch()..start();
      await gradingService.loadModel();
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(10), reason: 'Load kedua harus instan karena cache');
    });

    test('2. Test Inference Output Format & Isolate Execution', () async {
      // Buat gambar sampel hijau (Green dominan)
      final imageFile = createTestImage('sampel_hijau.jpg', 30, 200, 30);

      // Pastikan model sudah terload
      await gradingService.loadModel();

      final stopwatch = Stopwatch()..start();
      final result = await gradingService.inferGrade(imageFile);
      stopwatch.stop();

      // Cek format output
      expect(result, isA<Map<String, dynamic>>());
      expect(result.containsKey('grade'), isTrue);
      expect(result.containsKey('confidence'), isTrue);
      expect(result.containsKey('scores'), isTrue);
      expect(result.containsKey('inference_mode'), isTrue);

      expect(result['grade'], anyOf('A', 'B', 'C'));
      expect(result['confidence'], isA<double>());
      expect(result['confidence'], greaterThanOrEqualTo(0.0));
      expect(result['confidence'], lessThanOrEqualTo(1.0));
      expect(result['inference_mode'], equals('simulated'));

      // Verifikasi non-blocking isolate run (harus selesai dalam batas waktu wajar)
      expect(stopwatch.elapsedMilliseconds, lessThan(800), reason: 'Inferensi dan preprocessing isolate harus responsif');
    });

    test('3. Test Confidence Threshold & Class Matching (Grade A)', () async {
      // Hijau dominan (kualitas prima segar) -> Grade A
      final greenImage = createTestImage('kualitas_a.jpg', 20, 180, 20);

      final result = await gradingService.inferGrade(greenImage);
      
      expect(result['grade'], equals('A'));
      expect(result['confidence'], greaterThan(0.75), reason: 'Confidence score untuk Grade A harus tinggi');
      expect(result['scores']['A'], greaterThan(result['scores']['B']));
      expect(result['scores']['A'], greaterThan(result['scores']['C']));
    });

    test('4. Test Confidence Threshold & Class Matching (Grade B)', () async {
      // Campuran/Netral (kuning atau abu-abu merata) -> Grade B
      final yellowImage = createTestImage('kualitas_b.jpg', 150, 150, 150);

      final result = await gradingService.inferGrade(yellowImage);

      expect(result['grade'], equals('B'));
      expect(result['confidence'], greaterThan(0.60), reason: 'Confidence score untuk Grade B harus memadai');
      expect(result['scores']['B'], greaterThan(result['scores']['A']));
      expect(result['scores']['B'], greaterThan(result['scores']['C']));
    });

    test('5. Test Confidence Threshold & Class Matching (Grade C)', () async {
      // Merah/Kecokelatan dominan (sayur/buah tidak segar atau matang berlebih) -> Grade C
      final brownImage = createTestImage('kualitas_c.jpg', 180, 30, 30);

      final result = await gradingService.inferGrade(brownImage);

      expect(result['grade'], equals('C'));
      expect(result['confidence'], greaterThan(0.65), reason: 'Confidence score untuk Grade C harus tinggi');
      expect(result['scores']['C'], greaterThan(result['scores']['A']));
      expect(result['scores']['C'], greaterThan(result['scores']['B']));
    });

    test('6. Test Error Handling on Missing File', () async {
      final missingFile = File('${tempDir.path}/non_existent.jpg');

      expect(
        () => gradingService.inferGrade(missingFile),
        throwsA(isA<Exception>()),
        reason: 'Inferensi pada berkas yang tidak ada harus melempar exception',
      );
    });
  });
}
