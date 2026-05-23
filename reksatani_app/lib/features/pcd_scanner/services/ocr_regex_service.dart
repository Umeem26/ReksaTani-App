import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrRegexService {
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Membaca text dari file nota dan mengekstrak angka Berat serta Harga menggunakan Regex
  Future<Map<String, String>> ekstrakDataNota(String imagePath) async {
    String beratTebakan = '';
    String hargaTebakan = '';

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      // Menggabungkan seluruh baris text menjadi huruf kecil agar mudah dicocokkan
      String fullText = recognizedText.text.toLowerCase();

      // 1. SKRIP REGEX UNTUK BERAT (Mencari pola angka sebelum/sesudah kata kg, berat, netto, net)
      // Contoh target text: "berat: 150 kg", "netto 75kg", "total 120"
      final RegExp beratRegex = RegExp(r'(?:berat|netto|net|total)?\s*[:=]?\s*(\d+)\s*(?:kg|kilogram)?');
      final matchBerat = beratRegex.firstMatch(fullText);
      if (matchBerat != null && matchBerat.groupCount >= 1) {
        beratTebakan = matchBerat.group(1) ?? '';
      }

      // 2. SKRIP REGEX UNTUK HARGA (Mencari pola angka setelah kata rp, @, harga, atau nominal besar)
      // Contoh target text: "harga/kg: 8500", "rp. 9000", "@12000"
      final RegExp hargaRegex = RegExp(r'(?:harga|rp|@)\s*[\.\/kg]*\s*[:=]?\s*(\d{4,6})');
      final matchHarga = hargaRegex.firstMatch(fullText);
      if (matchHarga != null && matchHarga.groupCount >= 1) {
        hargaTebakan = matchHarga.group(1) ?? '';
      }

    } catch (e) {
      print("Error saat menjalankan OCR Modul 8: $e");
    }

    return {
      'berat': beratTebakan,
      'harga': hargaTebakan,
    };
  }

  // Wajib diclose untuk mencegah memory leak pada RAM hardware HP
  void dispose() {
    _textRecognizer.close();
  }
}