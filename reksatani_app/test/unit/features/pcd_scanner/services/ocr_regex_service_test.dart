import 'package:flutter_test/flutter_test.dart';
import 'package:reksatani_app/features/pcd_scanner/services/ocr_regex_service.dart';

void main() {
  late OcrRegexService service;

  setUp(() {
    service = OcrRegexService();
  });

  group('OcrRegexService - Regex Parsing Unit Tests', () {
    test('TC-OCR-001: Positive - Perfect text format extraction', () {
      const text = "Nota ReksaTani\nBerat: 150 kg\nHarga: 8500";
      final result = service.parseText(text);

      expect(result['berat'], '150');
      expect(result['harga'], '8500');
    });

    test('TC-OCR-002: Positive - Alternative keywords (netto, rp)', () {
      const text = "INFO BARANG\nNetto 75kg\nRP. 9000";
      final result = service.parseText(text);

      expect(result['berat'], '75');
      expect(result['harga'], '9000');
    });

    test('TC-OCR-003: Edge Case - Scrambled/Noisy text', () {
      const text = "Total brt: 120 !kg!\nharga/kg :: 12000 rupiah";
      final result = service.parseText(text);

      expect(result['berat'], '120');
      expect(result['harga'], '12000');
    });

    test('TC-OCR-004: Negative - Missing or invalid data', () {
      const text = "Kertas Kosong\nTidak ada angka\nStatus: Aman";
      final result = service.parseText(text);

      expect(result['berat'], '');
      expect(result['harga'], '');
    });

    test('TC-OCR-005: Edge Case - Large numbers and special characters', () {
      const text = "Net 1000\n@150000";
      final result = service.parseText(text);

      expect(result['berat'], '1000');
      expect(result['harga'], '150000');
    });
  });
}
