import 'dart:async';
import 'dart:io';
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

  // ─── MODUL 6: Eksekusi Pelurusan Sudut Nota ───
  Future<String> prosesWarpingNota(String imagePath) async {
    try {
      final fileNotaAsli = File(imagePath);
      final fileNotaLurus = await _warpingService.warpNota(fileNotaAsli);
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

  // ─── MODUL 9: Tebak Grade Komoditas (Kualitas) menggunakan TFLite ───
  Future<String> prosesTebakGrade(String imagePath) async {
    try {
      final fileBarang = File(imagePath);
      final hasilGrading = await _gradingMlService.inferGrade(fileBarang);
      return hasilGrading['grade'] as String;
    } catch (e) {
      // Fallback grade default jika terjadi error
      return 'A'; 
    }
  }

  // ─── MODUL 10: Grading Lengkap + Confidence Score untuk Sweeper ───
  /// Mengembalikan hasil inferensi lengkap termasuk confidence dan semua skor.
  /// Digunakan oleh Confidence Sweeper UI untuk menampilkan visual bar.
  Future<Map<String, dynamic>> prosesGradingLengkap(String imagePath) async {
    try {
      final fileBarang = File(imagePath);
      final hasilGrading = await _gradingMlService.inferGrade(fileBarang);
      return hasilGrading;
    } catch (e) {
      // Fallback: kembalikan grade A dengan confidence rendah agar sweeper aktif
      return {
        'grade': 'A',
        'confidence': 0.0,
        'scores': {'A': 0.0, 'B': 0.0, 'C': 0.0},
        'inference_mode': 'fallback_error',
      };
    }
  }
}