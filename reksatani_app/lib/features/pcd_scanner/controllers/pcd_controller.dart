import 'dart:async';
import 'dart:io';
import '../services/document_warping_service.dart';
import '../services/image_segmentation_service.dart'; // 👈 Daftarkan service Modul 7

class PcdController {
  final DocumentWarpingService _warpingService = DocumentWarpingService();
  final ImageSegmentationService _segmentationService = ImageSegmentationService(); // 👈 Inisialisasi

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
      // Memotong objek non-hijau di latar belakang komoditas
      final fileBarangMurni = await _segmentationService.segmenLatarKomoditas(fileBarangAsli);
      return fileBarangMurni.path;
    } catch (e) {
      return imagePath;
    }
  }

  // ─── MODUL 8: (Akan Dikerjakan Nanti) ───
  Future<String> prosesTebakGrade(String imagePath) async {
    await Future.delayed(const Duration(seconds: 2));
    return 'A'; 
  }
}