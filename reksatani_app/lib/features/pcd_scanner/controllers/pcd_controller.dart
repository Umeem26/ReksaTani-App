import 'dart:async';
import 'dart:io';
import '../services/document_warping_service.dart';
import '../services/image_segmentation_service.dart';
import '../services/ocr_regex_service.dart'; // 👈 Impor service baru Modul 8
import '../services/grading_ml_service.dart'; // 👈 Impor GradingMlService Modul 9

class PcdController {
  final DocumentWarpingService _warpingService = DocumentWarpingService();
  final ImageSegmentationService _segmentationService = ImageSegmentationService();
  final OcrRegexService _ocrRegexService = OcrRegexService(); // 👈 Inisialisasi Modul 8
  final GradingMlService _gradingMlService; // 👈 Inisialisasi Modul 9

  PcdController({GradingMlService? gradingMlService})
      : _gradingMlService = gradingMlService ?? GradingMlService();

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
}