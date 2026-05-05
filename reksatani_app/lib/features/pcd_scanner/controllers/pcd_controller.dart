import 'dart:async';

class PcdController {
  Future<String> prosesTebakGrade(String imagePath) async {
    // Simulasi waktu loading pemrosesan ML (2 detik)
    await Future.delayed(const Duration(seconds: 2));
    
    // Anggap saja algoritma PCD mu mendeteksi komoditas ini kualitasnya A
    return 'A'; 
  }
}