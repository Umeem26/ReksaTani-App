import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:reksatani_app/features/pcd_scanner/controllers/pcd_controller.dart';
import 'package:reksatani_app/features/pcd_scanner/services/grading_ml_service.dart';

ScanResult _ok(String label, double keyakinan) =>
    ScanResult(status: ScanStatus.ok, commodity: label, routerConfidence: keyakinan);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PcdController.saranDari', () {
    test('router yakin: saran berisi label dan keyakinan', () {
      final s = PcdController.saranDari(_ok('kelapa_sawit', 0.87))!;
      expect(s.label, 'kelapa_sawit');
      expect(s.keyakinan, 0.87);
    });

    test('tepat di ambang: ada saran; sedikit di bawah: tidak ada', () {
      expect(PcdController.saranDari(_ok('kopi', PcdController.ambangSaran)), isNotNull);
      expect(PcdController.saranDari(_ok('kopi', PcdController.ambangSaran - 0.001)), isNull);
    });

    test('bukan komoditas, keyakinan rendah, atau gagal: tidak ada saran', () {
      expect(
        PcdController.saranDari(const ScanResult(status: ScanStatus.notCommodity, routerConfidence: 0.9)),
        isNull,
      );
      expect(
        PcdController.saranDari(const ScanResult(
          status: ScanStatus.lowConfidence,
          commodity: 'gabah',
          routerConfidence: 0.9,
        )),
        isNull,
      );
      expect(PcdController.saranDari(ScanResult.error('model tidak ada')), isNull);
    });

    test('status ok tanpa label tidak menjadi saran', () {
      expect(
        PcdController.saranDari(const ScanResult(status: ScanStatus.ok, routerConfidence: 0.99)),
        isNull,
      );
    });
  });

  group('GradingMlService.sarankanKomoditas', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('saran_komoditas'));
    tearDown(() async => dir.delete(recursive: true));

    test('hanya router: hasilnya tidak pernah membawa grade', () async {
      final f = File('${dir.path}/hijau.jpg')
        ..writeAsBytesSync(img.encodeJpg(img.fill(img.Image(width: 50, height: 50),
            color: img.ColorRgb8(30, 200, 30))));

      final hasil = await GradingMlService(isTestMode: true).sarankanKomoditas(f);

      expect(hasil.status, ScanStatus.ok);
      expect(hasil.commodity, isNotNull);
      expect(hasil.grade, isNull);
      expect(hasil.gradeScores, isEmpty);
    });

    test('lewat PcdController: berkas hilang menjadi error, bukan lemparan', () async {
      final c = PcdController(gradingMlService: GradingMlService(isTestMode: true));

      final hasil = await c.prosesSaranKomoditas('${dir.path}/tidak_ada.jpg');

      expect(hasil.status, ScanStatus.error);
      expect(PcdController.saranDari(hasil), isNull);
    });
  });
}
