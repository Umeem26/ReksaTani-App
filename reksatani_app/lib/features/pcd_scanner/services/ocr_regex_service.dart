import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrRegexService {
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Membaca text dari file nota dan mengekstrak data berat, harga, nama, desa, dan komoditas
  Future<Map<String, String>> ekstrakDataNota(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      return parseText(recognizedText.text);
    } catch (e) {
      print("Error saat menjalankan OCR Modul 8: $e");
      return {
        'berat': '',
        'harga': '',
        'nama': '',
        'desa': '',
        'komoditas': '',
      };
    }
  }

  String cleanTextValue(String value) {
    // Hentikan jika ada spasi berturut-turut (2 atau lebih) atau tab yang mengindikasikan kolom baru
    final multiSpaceIndex = value.indexOf(RegExp(r'\s{2,}|\t'));
    if (multiSpaceIndex != -1) {
      value = value.substring(0, multiSpaceIndex);
    }
    
    // Pecah per spasi dan saring keyword pengganggu
    final keywords = {
      'berat', 'netto', 'net', 'total', 'qty', 'harga', 'rp', 'tgl', 'tanggal',
      'no', 'telepon', 'hp', 'alamat', 'desa', 'komoditas', 'pcd', 'grade',
      'kg', 'satuan', 'pcs', 'unit', 'jumlah', 'brt', 'timbangan', 'mitra'
    };
    
    final words = value.split(RegExp(r'\s+'));
    final cleanWords = <String>[];
    for (final word in words) {
      final cleanWord = word.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
      if (keywords.contains(cleanWord)) {
        break; // Berhenti jika mendeteksi kata kunci kolom lain
      }
      cleanWords.add(word);
    }
    return cleanWords.join(' ').trim();
  }

  String formatNumber(double val) {
    if (val == val.roundToDouble()) {
      return val.round().toString();
    } else {
      return val.toStringAsFixed(1);
    }
  }

  double? parseDoubleValue(String rawVal) {
    String cleanVal = rawVal.trim();
    if (cleanVal.contains('.') || cleanVal.contains(',')) {
      final parts = cleanVal.split(RegExp(r'[\.,]'));
      if (parts.length == 2 && parts[1].length != 3) {
        cleanVal = '${parts[0]}.${parts[1]}';
      } else {
        cleanVal = parts.join('');
      }
    }
    return double.tryParse(cleanVal);
  }

  Map<String, String> parseText(String text) {
    String beratTebakan = '';
    String hargaTebakan = '';
    String namaTebakan = '';
    String desaTebakan = '';
    String komoditasTebakan = '';

    final lines = text.split('\n');
    final String fullTextLower = text.toLowerCase();

    // 1. Deteksi Komoditas
    if (fullTextLower.contains('gabah') || fullTextLower.contains('padi') || fullTextLower.contains('gkp') || fullTextLower.contains('gkg')) {
      komoditasTebakan = 'gabah';
    } else if (fullTextLower.contains('robusta') || fullTextLower.contains('kopi') || fullTextLower.contains('biji kopi')) {
      komoditasTebakan = 'kopi robusta';
    } else if (fullTextLower.contains('sawit') || fullTextLower.contains('tbs') || fullTextLower.contains('kelapa sawit')) {
      komoditasTebakan = 'sawit';
    }

    // 2. Deteksi Nama Penjual
    final RegExp namaRegex = RegExp(
      r'(?:nama|petani|penjual|kepada|mitra|customer|client|ybs)\s*[:=\-]*\s*([a-zA-Z \t\.\,]{3,50})',
      caseSensitive: false,
    );
    final matchNama = namaRegex.firstMatch(text);
    if (matchNama != null) {
      final rawVal = matchNama.group(1) ?? '';
      final val = cleanTextValue(rawVal);
      if (val.length >= 3 && !RegExp(r'^(rp|no|tgl|tanggal|alamat|telepon|hp|netto|berat)$', caseSensitive: false).hasMatch(val)) {
        namaTebakan = val;
      }
    }

    // 3. Deteksi Desa / Alamat
    final RegExp desaRegex = RegExp(
      r'(?:desa|alamat|asal|wilayah|lokasi|tempat)\s*[:=\-]*\s*([a-zA-Z \t\.\,]{3,50})',
      caseSensitive: false,
    );
    final matchDesa = desaRegex.firstMatch(text);
    if (matchDesa != null) {
      final rawVal = matchDesa.group(1) ?? '';
      final val = cleanTextValue(rawVal);
      if (val.length >= 3 && !RegExp(r'^(rp|no|tgl|tanggal)$', caseSensitive: false).hasMatch(val)) {
        desaTebakan = val;
      }
    }

    // 4. Deteksi Angka (Berat, Harga) secara semantik
    final List<double> numbers = [];
    for (final line in lines) {
      final matches = RegExp(r'\d+(?:[\.,]\d+)?').allMatches(line);
      for (final match in matches) {
        final rawNum = match.group(0)!;
        final val = parseDoubleValue(rawNum);
        if (val != null && val > 0) {
          numbers.add(val);
        }
      }
    }

    // --- MATHEMATICAL SOLVER ---
    double? solvedWeight;
    double? solvedPrice;

    // Coba exact match dulu: w * p == t (toleransi pembulatan float < 0.1)
    for (int i = 0; i < numbers.length; i++) {
      for (int j = 0; j < numbers.length; j++) {
        if (i == j) continue;
        for (int k = 0; k < numbers.length; k++) {
          if (k == i || k == j) continue;
          final w = numbers[i];
          final p = numbers[j];
          final t = numbers[k];

          if (w >= 10 && w <= 4000 && p >= 1000 && p <= 200000) {
            if ((w * p - t).abs() < 0.1) {
              solvedWeight = w;
              solvedPrice = p;
              break;
            }
          }
        }
        if (solvedWeight != null) break;
      }
      if (solvedWeight != null) break;
    }

    // Coba toleransi jika belum ketemu (diff <= 100 atau percentDiff <= 0.02)
    if (solvedWeight == null) {
      for (int i = 0; i < numbers.length; i++) {
        for (int j = 0; j < numbers.length; j++) {
          if (i == j) continue;
          for (int k = 0; k < numbers.length; k++) {
            if (k == i || k == j) continue;
            final w = numbers[i];
            final p = numbers[j];
            final t = numbers[k];

            if (w >= 10 && w <= 4000 && p >= 1000 && p <= 200000) {
              final diff = (w * p - t).abs();
              final percentDiff = diff / (w * p);
              if (diff <= 100 || percentDiff <= 0.02) {
                solvedWeight = w;
                solvedPrice = p;
                break;
              }
            }
          }
          if (solvedWeight != null) break;
        }
        if (solvedWeight != null) break;
      }
    }

    if (solvedWeight != null && solvedPrice != null) {
      beratTebakan = formatNumber(solvedWeight);
      hargaTebakan = solvedPrice.round().toString();
    }

    // Pendekatan Regex khusus untuk Berat
    final RegExp beratRegex = RegExp(
      r'(?:berat|netto|net|total|qty|timbangan|jumlah|brt)\s*[:=\s]*\s*(\d+[\.,]?\d*)\s*(?:kg|kilogram|kgm)?',
      caseSensitive: false,
    );
    if (beratTebakan.isEmpty) {
      final matchBerat = beratRegex.firstMatch(fullTextLower);
      if (matchBerat != null) {
        final rawVal = matchBerat.group(1) ?? '';
        final val = parseDoubleValue(rawVal);
        if (val != null && val > 0) {
          beratTebakan = formatNumber(val);
        }
      }
    }

    // Suffix Regex matching untuk Berat (misal "120 kg")
    final RegExp beratSuffixRegex = RegExp(
      r'(\d+[\.,]?\d*)\s*(?:kg|kilogram|kgm)\b',
      caseSensitive: false,
    );
    if (beratTebakan.isEmpty) {
      final matchSuffix = beratSuffixRegex.firstMatch(fullTextLower);
      if (matchSuffix != null) {
        final rawVal = matchSuffix.group(1) ?? '';
        final val = parseDoubleValue(rawVal);
        if (val != null && val > 0) {
          beratTebakan = formatNumber(val);
        }
      }
    }

    // Pendekatan Regex khusus untuk Harga per kg (mendukung ribuan dot/comma)
    final RegExp hargaRegex = RegExp(
      r'(?:harga|rp|@|satuan|perkg)\s*(?:\/kg|/kgm)?\s*[:=\s]*\s*(?:rp\.?\s*)?(\d+(?:[\.,]\d+)?)',
      caseSensitive: false,
    );
    if (hargaTebakan.isEmpty) {
      final matchHarga = hargaRegex.firstMatch(fullTextLower);
      if (matchHarga != null) {
        final rawVal = matchHarga.group(1) ?? '';
        final val = parseDoubleValue(rawVal);
        if (val != null && val >= 1000 && val <= 200000) {
          hargaTebakan = val.round().toString();
        }
      }
    }

    // Suffix Regex matching untuk Harga (misal "8.500/kg")
    final RegExp hargaSuffixRegex = RegExp(
      r'(\d+(?:[\.,]\d+)?)\s*(?:\/kg|/kgm|per\s*kg)\b',
      caseSensitive: false,
    );
    if (hargaTebakan.isEmpty) {
      final matchSuffix = hargaSuffixRegex.firstMatch(fullTextLower);
      if (matchSuffix != null) {
        final rawVal = matchSuffix.group(1) ?? '';
        final val = parseDoubleValue(rawVal);
        if (val != null && val >= 1000 && val <= 200000) {
          hargaTebakan = val.round().toString();
        }
      }
    }

    // Cross-check semantik jika regex kosong
    if (beratTebakan.isEmpty || hargaTebakan.isEmpty) {
      final uniqueNumbers = numbers.toSet().toList()..sort();
      if (uniqueNumbers.isNotEmpty) {
        double? detectedHarga;
        double? detectedBerat;

        if (hargaTebakan.isEmpty) {
          for (final num in uniqueNumbers) {
            if (num >= 1500 && num <= 65000) {
              if (komoditasTebakan == 'sawit' && num <= 5000) {
                detectedHarga = num;
                break;
              } else if (komoditasTebakan == 'gabah' && num >= 4000 && num <= 12000) {
                detectedHarga = num;
                break;
              } else if (komoditasTebakan == 'kopi robusta' && num >= 20000 && num <= 60000) {
                detectedHarga = num;
                break;
              } else if (komoditasTebakan.isEmpty) {
                detectedHarga = num;
                break;
              }
            }
          }
        } else {
          detectedHarga = double.tryParse(hargaTebakan);
        }
        if (beratTebakan.isEmpty) {
          final List<double> beratCandidates = uniqueNumbers.where((n) {
            if (n == detectedHarga) return false;
            return n >= 10 && n <= 4000;
          }).toList();

          if (beratCandidates.isNotEmpty) {
            // Filter out numbers in range [2020, 2040] (likely years) if there are other candidates
            final nonYearCandidates = beratCandidates.where((n) => n < 2020 || n > 2040).toList();
            final candidatesWithoutYears = nonYearCandidates.isNotEmpty ? nonYearCandidates : beratCandidates;

            // Filter out <= 31 (dates) if there are larger candidates to avoid date stamps
            final largerCandidates = candidatesWithoutYears.where((n) => n > 31).toList();
            final selectedCandidates = largerCandidates.isNotEmpty ? largerCandidates : candidatesWithoutYears;
            
            // Sort descending to prefer larger weights
            selectedCandidates.sort((a, b) => b.compareTo(a));
            detectedBerat = selectedCandidates.first;
          }
        }

        if (hargaTebakan.isEmpty && detectedHarga != null) {
          hargaTebakan = detectedHarga.round().toString();
        }
        if (beratTebakan.isEmpty && detectedBerat != null) {
          beratTebakan = formatNumber(detectedBerat);
        }
      }
    }

    return {
      'berat': beratTebakan,
      'harga': hargaTebakan,
      'nama': namaTebakan,
      'desa': desaTebakan,
      'komoditas': komoditasTebakan,
    };
  }

  // Wajib diclose untuk mencegah memory leak pada RAM hardware HP
  void dispose() {
    _textRecognizer.close();
  }
}