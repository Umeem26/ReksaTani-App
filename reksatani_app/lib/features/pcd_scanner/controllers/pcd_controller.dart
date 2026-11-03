import 'dart:async';
import 'dart:io';
import 'dart:ui' show Offset;
import 'package:camera/camera.dart';
import '../services/document_warping_service.dart';
import '../services/image_segmentation_service.dart';
import '../services/ocr_regex_service.dart'; // 👈 Impor service baru Modul 8
import '../services/grading_ml_service.dart'; // 👈 Impor GradingMlService Modul 9
import '../services/confidence_validator.dart'; // 👈 Impor ConfidenceValidator Modul 10

class PcdController {
  final DocumentWarpingService _warpingService = DocumentWarpingService();
  final ImageSegmentationService _segmentationService = ImageSegmentationService();
  final OcrRegexService _ocrRegexService = OcrRegexService(); // 👈 Inisialisasi Modul 8
  final GradingMlService _gradingMlService; // 👈 Inisialisasi Modul 9
  final ConfidenceValidator confidenceValidator; // 👈 Inisialisasi Modul 10

  PcdController({
    GradingMlService? gradingMlService,
    ConfidenceValidator? confidenceValidator,
  })  : _gradingMlService = gradingMlService ?? GradingMlService(),
        confidenceValidator = confidenceValidator ?? ConfidenceValidator();

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

  // ─── MODUL 9/10: Grading Lengkap (router + grader) ───
  /// Mengembalikan [ScanResult] dengan status eksplisit. Kegagalan apa pun
  /// menghasilkan [ScanStatus.error] dengan grade null (tidak pernah Grade A).
  Future<ScanResult> prosesGradingLengkap(String imagePath) async {
    try {
      return await _gradingMlService.scanImage(File(imagePath));
    } catch (e) {
      return ScanResult.error('$e');
    }
  }
}
