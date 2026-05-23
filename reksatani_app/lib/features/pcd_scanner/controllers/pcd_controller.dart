import 'dart:async';
import 'dart:io';
import '../services/document_warping_service.dart';
import '../services/image_segmentation_service.dart';
import '../services/ocr_regex_service.dart'; // 👈 Impor service baru Modul 8

class PcdController {
  final DocumentWarpingService _warpingService = DocumentWarpingService();
  final ImageSegmentationService _segmentationService = ImageSegmentationService();
  final OcrRegexService _ocrRegexService = OcrRegexService(); // 👈 Inisialisasi Modul 8

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

  // ─── MODUL 8 PART B: Tebak Grade Komoditas (Kualitas) ───
  Future<String> prosesTebakGrade(String imagePath) async {
    // Simulasi pemrosesan Edge AI klasifikasi citra sayur/buah
    await Future.delayed(const Duration(milliseconds: 500));
    return 'A'; 
  }
}