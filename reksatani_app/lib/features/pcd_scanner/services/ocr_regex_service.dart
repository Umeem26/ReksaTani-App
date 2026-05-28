import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrRegexService {
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Membaca text dari file nota dan mengekstrak angka Berat serta Harga menggunakan Regex
  Future<Map<String, String>> ekstrakDataNota(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      return parseText(recognizedText.text);
    } catch (e) {
      print("Error saat menjalankan OCR Modul 8: $e");
      return {'berat': '', 'harga': ''};
    }
  }

  Map<String, String> parseText(String text) {
    String beratTebakan = '';
    String hargaTebakan = '';

    String fullText = text.toLowerCase();

    final RegExp beratRegex = RegExp(r'(?:berat|netto|net|total)?\s*[:=\s]*\s*(\d+)\s*(?:kg|kilogram)?');
    final matchBerat = beratRegex.firstMatch(fullText);
    if (matchBerat != null && matchBerat.groupCount >= 1) {
      beratTebakan = matchBerat.group(1) ?? '';
    }

    final RegExp hargaRegex = RegExp(r'(?:harga|rp|@)\s*[\.\/kg]*\s*[:=\s]*\s*(\d{4,6})');
    final matchHarga = hargaRegex.firstMatch(fullText);
    if (matchHarga != null && matchHarga.groupCount >= 1) {
      hargaTebakan = matchHarga.group(1) ?? '';
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