import 'dart:async';
import 'dart:io';
import 'dart:ui' show Offset;
import 'package:camera/camera.dart';
import '../services/document_warping_service.dart';
import '../services/image_segmentation_service.dart';
import '../services/ocr_regex_service.dart'; // 👈 Impor service baru Modul 8
import '../services/grading_ml_service.dart'; // 👈 Impor GradingMlService Modul 9

/// Saran komoditas dari router. Hanya saran: pengguna selalu mengonfirmasi
/// atau menggantinya, dan grade tidak pernah datang dari sini.
class SaranKomoditas {
  /// Label router: 'gabah' | 'kelapa_sawit' | 'kopi'.
  final String label;
  final double keyakinan;
  const SaranKomoditas(this.label, this.keyakinan);
}

class PcdController {
  final DocumentWarpingService _warpingService = DocumentWarpingService();
  final ImageSegmentationService _segmentationService = ImageSegmentationService();
  final OcrRegexService _ocrRegexService = OcrRegexService(); // 👈 Inisialisasi Modul 8
  final GradingMlService _gradingMlService; // 👈 Inisialisasi Modul 9

  PcdController({GradingMlService? gradingMlService})
      : _gradingMlService = gradingMlService ?? GradingMlService();

  /// Di bawah keyakinan router ini tidak ada saran; pengguna memilih manual.
  static const double ambangSaran = 0.5;

  /// Saran dari hasil router, atau null bila bukan komoditas, gagal, atau
  /// keyakinannya di bawah [ambangSaran].
  static SaranKomoditas? saranDari(ScanResult scan) {
    final label = scan.commodity;
    if (scan.status != ScanStatus.ok || label == null) return null;
    if (scan.routerConfidence < ambangSaran) return null;
    return SaranKomoditas(label, scan.routerConfidence);
  }

  /// Memuat model TFLite dari aset perangkat secara aman.
  Future<void> loadModel() async {
    await _gradingMlService.loadModel();
  }

  /// Memproses klasifikasi komoditas langsung dari stream kamera (CameraImage).
  /// Memakai fungsi keputusan yang sama dengan foto diam; gagal -> [ScanStatus.error], tanpa grade.
  Future<ScanResult> prosesKlasifikasiLive(CameraImage image) async {
    try {
      final prep = _gradingMlService.prepareCameraImage(image);
      return await _gradingMlService.inferFromTensor(prep);
    } catch (e) {
      return ScanResult.error('$e');
    }
  }

  // ─── MODUL 6: Eksekusi Pelurusan Sudut Nota ───
  Future<String> prosesWarpingNota(String imagePath, {List<Offset>? manualCorners}) async {
    try {
      final fileNotaAsli = File(imagePath);
      final fileNotaLurus = await _warpingService.warpNota(fileNotaAsli, manualCorners: manualCorners);
      return fileNotaLurus.path;
    } catch (e) {
      return imagePath; 
    }
  }

  // ─── MODUL 7: Eksekusi Pemotongan Latar Belakang Komoditas ───
  Future<String> prosesSegmentasiBarang(String imagePath) async {
    try {
      final fileBarangAsli = File(imagePath);
      final fileBarangMurni = await _segmentationService.segmenLatarKomoditas(fileBarangAsli);
      return fileBarangMurni.path;
    } catch (e) {
      return imagePath;
    }
  }

  // ─── 🛠️ MODUL 8: Ekstraksi Teks Nota Berbasis OCR & Regex ───
  Future<Map<String, String>> prosesOcrNota(String imagePath) async {
    return await _ocrRegexService.ekstrakDataNota(imagePath);
  }

  // ─── MODUL 9: Saran Komoditas (router saja) ───
  /// Model grader tidak dipanggil: grade A/B/C ditentukan manusia lewat rubrik.
  /// Kegagalan apa pun menghasilkan [ScanStatus.error], yang berarti tanpa saran.
  Future<ScanResult> prosesSaranKomoditas(String imagePath) async {
    try {
      return await _gradingMlService.sarankanKomoditas(File(imagePath));
    } catch (e) {
      return ScanResult.error('$e');
    }
  }
}
