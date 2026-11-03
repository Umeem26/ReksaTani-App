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

  static bool _endsAtLineEnd(String text, int end) =>
      end >= text.length || text[end] == '\n' || text[end] == '\r';

  /// Membuang gelar di depan (Bpk., Pak, Ibu, H., Hj., Drs., ...) dan gelar
  /// akademik setelah koma (", S.P.").
  String cleanNameValue(String value) {
    String v = value.trim();
    final comma = v.indexOf(',');
    if (comma > 0) v = v.substring(0, comma).trim();
    final stripped = v.replaceFirst(
      RegExp(r'^(?:(?:bpk|bapak|pak|ibu|bu|hj|h|haji|hajah|drs|dra|dr|ir|sdr|sdri)\.?\s+)+', caseSensitive: false),
      '',
    ).trim();
    return stripped.length >= 3 ? stripped : v;
  }

  /// [endsAtLineEnd]: nilai berakhir di akhir baris. Kata kunci di posisi
  /// terakhir lalu dianggap bagian nama ("Agus Netto"), bukan label kolom.
  String cleanTextValue(String value, {bool endsAtLineEnd = false}) {
    // Hentikan jika ada spasi berturut-turut (2 atau lebih) atau tab yang mengindikasikan kolom baru
    final multiSpaceIndex = value.indexOf(RegExp(r'\s{2,}|\t'));
    if (multiSpaceIndex != -1) {
      value = value.substring(0, multiSpaceIndex);
    }
    
    // Pecah per spasi dan saring keyword pengganggu
    final keywords = {
      'berat', 'netto', 'net', 'total', 'qty', 'harga', 'rp', 'tgl', 'tanggal',
      'no', 'telepon', 'hp', 'alamat', 'desa', 'komoditas', 'pcd', 'grade',
      'kg', 'satuan', 'pcs', 'unit', 'jumlah', 'brt', 'timbangan', 'mitra',
      'kec', 'kecamatan', 'kab', 'kabupaten', 'kel', 'kelurahan'
    };
    
    final words = value.trim().split(RegExp(r'\s+'));
    final cleanWords = <String>[];
    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      final cleanWord = word.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
      final bool isLast = i == words.length - 1;
      if (keywords.contains(cleanWord) && !(endsAtLineEnd && isLast && cleanWords.isNotEmpty)) {
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

  /// Parse satu token angka mentah (boleh berisi pemisah ribuan/desimal dan
  /// salah-baca OCR). Mengembalikan null bila token ambigu.
  double? parseDoubleValue(String rawVal) {
    final canonical = canonicalNumber(rawVal.trim());
    return canonical == null ? null : double.tryParse(canonical);
  }

  // Salah-baca OCR yang umum di dalam token angka.
  static const Map<String, String> _confusions = {
    'O': '0', 'o': '0', 'l': '1', 'I': '1', 'S': '5', 'B': '8',
  };
  static const String _confusionChars = 'OolISB';
  static final RegExp _numericRun = RegExp(r'[0-9OolISB]+(?:[.,][0-9OolISB]+)*');
  static final RegExp _spaceGrouped = RegExp(r'(?<![\d.,])(\d{1,3})((?: \d{3})+)(?!\d)');

  /// Mengubah token angka menjadi bentuk kanonik: digit saja, titik sebagai
  /// pemisah desimal ("1.250,5" -> "1250.5", "1.700.000" -> "1700000",
  /// "8.S00" -> "8500"). Mengembalikan null bila struktur pemisah ambigu
  /// (mis. "12.06.2026", "1.2500", "1250.000").
  String? canonicalNumber(String raw) {
    if (raw.isEmpty) return null;
    final buf = StringBuffer();
    for (final ch in raw.split('')) {
      buf.write(_confusions[ch] ?? ch);
    }
    final t = buf.toString();
    if (!RegExp(r'^\d+(?:[.,]\d+)*$').hasMatch(t)) return null;
    if (!t.contains('.') && !t.contains(',')) return t;

    final seps = RegExp(r'[.,]').allMatches(t).map((m) => m.group(0)!).toList();
    final groups = t.split(RegExp(r'[.,]'));

    bool validThousands(List<String> g) {
      if (g.isEmpty || g.first.isEmpty || g.first.length > 3) return false;
      if (g.first.startsWith('0') && g.length > 1) return false;
      return g.skip(1).every((x) => x.length == 3);
    }

    String intPart;
    String decPart = '';
    final bool hasDot = seps.contains('.');
    final bool hasComma = seps.contains(',');

    if (hasDot && hasComma) {
      // Pemisah terakhir = desimal (harus muncul sekali), sisanya ribuan jenis lain.
      final dec = seps.last;
      if (seps.where((x) => x == dec).length != 1) return null;
      final intGroups = groups.sublist(0, groups.length - 1);
      if (!validThousands(intGroups)) return null;
      intPart = intGroups.join();
      decPart = groups.last;
    } else if (seps.length > 1) {
      if (!validThousands(groups)) return null;
      intPart = groups.join();
    } else {
      final after = groups[1];
      if (after.length == 3) {
        if (validThousands(groups)) {
          intPart = groups.join();
        } else if (groups[0] == '0') {
          intPart = '0';
          decPart = after;
        } else {
          return null; // "1250.000": ribuan atau desimal? ambigu.
        }
      } else if (after.length <= 2) {
        intPart = groups[0];
        decPart = after;
      } else {
        return null; // "1.2500": ambigu.
      }
    }

    intPart = intPart.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    decPart = decPart.replaceFirst(RegExp(r'0+$'), '');
    return decPart.isEmpty ? intPart : '$intPart.$decPart';
  }

  /// Menormalkan semua token angka dalam [text] ke bentuk kanonik.
  /// Huruf O/o->0, l/I->1, S->5, B->8 hanya diganti di dalam token angka
  /// (token harus berisi digit asli, huruf tidak lebih banyak dari digit, dan
  /// huruf yang menempel ke kata lain diabaikan). Token ambigu diganti '#'
  /// supaya tidak pernah dipakai sebagai berat/harga.
  String normalizeNumbers(String text) {
    final out = <String>[];
    for (final line in text.split('\n')) {
      // Ribuan dengan spasi: "Rp 8 500" atau "1 700 000".
      String l = line.replaceAllMapped(_spaceGrouped, (m) {
        final groupsCount = ' '.allMatches(m.group(2)!).length;
        final before = line.substring(0, m.start).toLowerCase();
        final rpContext = RegExp(r'rp\.?\s*$').hasMatch(before);
        if (groupsCount >= 2 || rpContext) {
          return m.group(0)!.replaceAll(' ', '');
        }
        return m.group(0)!;
      });

      final sb = StringBuffer();
      int last = 0;
      for (final m in _numericRun.allMatches(l)) {
        sb.write(l.substring(last, m.start));
        last = m.end;
        String run = m.group(0)!;
        String prefix = '';
        String suffix = '';

        final bool letterBefore = m.start > 0 && RegExp(r'[A-Za-z]').hasMatch(l[m.start - 1]);
        final String rest = l.substring(m.end);
        final bool letterAfter = rest.isNotEmpty &&
            RegExp(r'[A-Za-z]').hasMatch(rest[0]) &&
            !RegExp(r'^(?:kg|kilo)', caseSensitive: false).hasMatch(rest);

        if (letterBefore) {
          int i = 0;
          while (i < run.length && (_confusionChars.contains(run[i]) || run[i] == '.' || run[i] == ',')) {
            i++;
          }
          prefix = run.substring(0, i);
          run = run.substring(i);
        }
        if (letterAfter) {
          int j = run.length;
          while (j > 0 && (_confusionChars.contains(run[j - 1]) || run[j - 1] == '.' || run[j - 1] == ',')) {
            j--;
          }
          suffix = run.substring(j);
          run = run.substring(0, j);
        }

        final int digits = RegExp(r'\d').allMatches(run).length;
        final int letters = run.split('').where((c) => _confusionChars.contains(c)).length;
        if (digits == 0 || letters > digits) {
          sb.write(prefix + run + suffix);
          continue;
        }
        if (RegExp(r'^\d+$').hasMatch(run)) {
          sb.write(prefix + run + suffix); // sudah bersih, pertahankan nol di depan (no. HP)
          continue;
        }
        final canonical = canonicalNumber(run);
        sb.write(prefix + (canonical ?? '#') + suffix);
      }
      sb.write(l.substring(last));
      out.add(sb.toString());
    }
    return out.join('\n');
  }

  Map<String, String> parseText(String rawText) {
    // Teks asli dipakai untuk nama/desa; angka dibaca dari teks yang sudah dinormalkan.
    final String text = normalizeNumbers(rawText);
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
      r"(?:nama|petani|penjual|kepada|mitra|customer|client|ybs)\s*[:=\-]*\s*([a-zA-Z'’ \t\.\,]{3,50})",
      caseSensitive: false,
    );
    final matchNama = namaRegex.firstMatch(rawText);
    if (matchNama != null) {
      final rawVal = matchNama.group(1) ?? '';
      final val = cleanNameValue(cleanTextValue(rawVal, endsAtLineEnd: _endsAtLineEnd(rawText, matchNama.end)));
      if (val.length >= 3 && !RegExp(r'^(rp|no|tgl|tanggal|alamat|telepon|hp|netto|berat)$', caseSensitive: false).hasMatch(val)) {
        namaTebakan = val;
      }
    }

    // 3. Deteksi Desa / Alamat
    final RegExp desaRegex = RegExp(
      r'(?:desa|alamat|asal|wilayah|lokasi|tempat)\s*[:=\-]*\s*([a-zA-Z \t\.\,]{3,50})',
      caseSensitive: false,
    );
    final matchDesa = desaRegex.firstMatch(rawText);
    if (matchDesa != null) {
      final rawVal = matchDesa.group(1) ?? '';
      final val = cleanTextValue(rawVal, endsAtLineEnd: _endsAtLineEnd(rawText, matchDesa.end));
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
        final val = double.tryParse(rawNum);
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
        final val = double.tryParse(rawVal);
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
        final val = double.tryParse(rawVal);
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
        final val = double.tryParse(rawVal);
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
        final val = double.tryParse(rawVal);
        if (val != null && val >= 1000 && val <= 200000) {
          hargaTebakan = val.round().toString();
        }
      }
    }

    // Harga = total / berat bila nota hanya mencantumkan total.
    if (hargaTebakan.isEmpty && beratTebakan.isNotEmpty) {
      final berat = double.tryParse(beratTebakan);
      final matchTotal = RegExp(
        r'(?:total|jumlah\s*bayar|grand\s*total)\s*[:=]?\s*(?:rp\.?\s*)?(\d+(?:\.\d+)?)',
        caseSensitive: false,
      ).firstMatch(fullTextLower);
      final total = matchTotal == null ? null : double.tryParse(matchTotal.group(1)!);
      if (berat != null && berat > 0 && total != null && total != berat) {
        final p = total / berat;
        if (p >= 1000 && p <= 200000 && (p - p.round()).abs() < 0.01) {
          hargaTebakan = p.round().toString();
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
          final double? beratSudah = double.tryParse(beratTebakan);
          for (final num in uniqueNumbers) {
            if (num == beratSudah) continue;
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