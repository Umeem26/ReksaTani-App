import 'dart:async';
import 'dart:io';
import '../services/document_warping_service.dart';

class PcdController {
  final DocumentWarpingService _warpingService = DocumentWarpingService();

  // ─── MODUL 6: Eksekusi Warping Nota ───
  Future<String> prosesWarpingNota(String imagePath) async {
    try {
      final fileNotaAsli = File(imagePath);
      // Proses pelurusan sudut nota berjalan di sini
      final fileNotaLurus = await _warpingService.warpNota(fileNotaAsli);
      
      return fileNotaLurus.path;
    } catch (e) {
      // Jika error, amankan dengan mengembalikan foto aslinya
      return imagePath; 
    }
  }

  // ─── MODUL 8: (Akan Dikerjakan Nanti) ───
  Future<String> prosesTebakGrade(String imagePath) async {
    // Simulasi waktu loading pemrosesan ML (2 detik)
    await Future.delayed(const Duration(seconds: 2));
    
    // Anggap saja algoritma PCD mu mendeteksi komoditas ini kualitasnya A
    return 'A'; 
  }
}