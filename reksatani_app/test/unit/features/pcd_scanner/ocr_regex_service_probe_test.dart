// Probe cases from AUDIT_PCD_LOCAL.md §7 (43 synthetic Indonesian receipt strings),
// plus guards that ambiguous number tokens never become a price.
import 'package:flutter_test/flutter_test.dart';
import 'package:reksatani_app/features/pcd_scanner/services/ocr_regex_service.dart';

class Case {
  final String id;
  final String text;
  final Map<String, String> expect; // only keys listed are checked
  final String note;
  const Case(this.id, this.text, this.expect, [this.note = '']);
}

const cases = <Case>[
  // ── Thousand / decimal separators ──
  Case('S01', 'Berat: 1.250 kg\nHarga: 8.500', {'berat': '1250', 'harga': '8500'}, 'dot thousands'),
  Case('S02', 'Berat 125 kg\nHarga 10.000/kg\nTotal 1.250.000', {'berat': '125', 'harga': '10000'}, 'total with 2 dot groups'),
  Case('S03', 'Berat 125 kg\nHarga 10,000\nTotal 1,250,000', {'berat': '125', 'harga': '10000'}, 'comma thousands'),
  Case('S04', 'Netto 12,5 kg\nHarga 9.000', {'berat': '12.5', 'harga': '9000'}, 'comma decimal, w<10? no, 12.5'),
  Case('S05', 'Gabah\nBerat 12.5kg\nHarga 6.500', {'berat': '12.5', 'harga': '6500'}, 'dot decimal glued kg'),
  Case('S06', 'Kopi\nBerat 40 kg\nRp 12.500/kg', {'berat': '40', 'harga': '12500'}, 'Rp x/kg'),
  Case('S07', 'Berat 100 kg\nHarga 8500\nTotal 850000', {'berat': '100', 'harga': '8500'}, 'solver plain total'),
  Case('S08', 'Berat 1.250,5 kg\nHarga 6.000', {'berat': '1250.5', 'harga': '6000'}, 'ID decimal w/ thousands'),
  Case('S09', 'Berat 1,250.5 kg\nHarga 6,000', {'berat': '1250.5', 'harga': '6000'}, 'US decimal w/ thousands'),
  Case('S10', 'Berat 300 kg\nHarga 8.500,00', {'berat': '300', 'harga': '8500'}, 'price with ,00 cents'),
  Case('S11', 'Berat 300 kg\nHarga Rp 8.500,-', {'berat': '300', 'harga': '8500'}, 'price ,- suffix'),
  Case('S12', 'Berat 200 kg\nHarga : Rp. 8 500', {'berat': '200', 'harga': '8500'}, 'space as thousands sep'),
  Case('S13', 'Berat 250 kg\nHarga 5.000\nTotal Rp 1.250.000', {'berat': '250', 'harga': '5000'}, 'Rp total'),
  // ── OCR confusions ──
  Case('C01', 'Berat: 1O0 kg\nHarga: 8500', {'berat': '100'}, 'O for 0 in weight'),
  Case('C02', 'Berat: 150 kg\nHarga: 85OO', {'harga': '8500'}, 'O for 0 in price'),
  Case('C03', 'Berat: l20 kg\nHarga: 8500', {'berat': '120'}, 'l for 1'),
  Case('C04', 'Berat: 120 kg\nHarga: 8.S00', {'harga': '8500'}, 'S for 5'),
  Case('C05', 'Berat: I50 kg\nHarga: 9000', {'berat': '150'}, 'I for 1'),
  Case('C06', 'Berat: 2B0 kg\nHarga: 9000', {'berat': '280'}, 'B for 8'),
  // ── Spacing / layout ──
  Case('L01', 'Berat   :   150    kg\nHarga  :   8500', {'berat': '150', 'harga': '8500'}, 'extra spaces'),
  Case('L02', 'Berat\n150 kg\nHarga\n8500', {'berat': '150', 'harga': '8500'}, 'label/value on separate lines'),
  Case('L03', 'Berat:150kg Harga:8500', {'berat': '150', 'harga': '8500'}, 'single line, no spaces'),
  Case('L04', 'BERAT: 150 KG\nHARGA: RP 8.500', {'berat': '150', 'harga': '8500'}, 'all caps'),
  Case('L05', 'Tgl 12/06/2026\nBerat 45 kg\nHarga 9000', {'berat': '45', 'harga': '9000'}, 'date noise'),
  Case('L06', 'HP 081234567890\nBerat 100 kg\nHarga 8500', {'berat': '100', 'harga': '8500'}, 'phone noise'),
  Case('L07', 'Berat Kotor 520 kg\nTara 20 kg\nNetto 500 kg\nHarga 6000', {'berat': '500', 'harga': '6000'}, 'gross/tare/net'),
  Case('L08', 'Berat 8 kg\nHarga 9000', {'berat': '8', 'harga': '9000'}, 'weight < 10'),
  Case('L09', 'Sawit\nNetto 5.200 kg\nHarga 2.400', {'berat': '5200', 'harga': '2400'}, 'weight > 4000 (truck)'),
  Case('L10', 'Berat 200 kg\nTotal 1.700.000', {'berat': '200', 'harga': '8500'}, 'price must be derived from total'),
  Case('L11', 'No. Nota 0012\nBerat 75 kg\n@ 8500', {'berat': '75', 'harga': '8500'}, 'nota number + @'),
  // ── Commodity realistic ──
  Case('K01', 'Kopi Robusta\nBerat 60 kg\nHarga 45.000/kg\nTotal 2.700.000', {'berat': '60', 'harga': '45000', 'komoditas': 'kopi robusta'}),
  Case('K02', 'TBS Sawit\nNetto 2.350 kg\nHarga 2.450\nTotal 5.757.500', {'berat': '2350', 'harga': '2450', 'komoditas': 'sawit'}),
  Case('K03', 'Gabah GKP\nBerat 1.500 kg\nHarga 6.800\nTotal 10.200.000', {'berat': '1500', 'harga': '6800', 'komoditas': 'gabah'}),
  Case('K04', 'Pembeli: Toko Kopi Jaya\nKomoditas: Gabah\nBerat 300 kg\nHarga 6500', {'komoditas': 'gabah'}, 'shop name contains kopi'),
  // ── Names / villages ──
  Case('N01', 'Nama: Bpk. H. Ahmad Sutisna\nBerat 100 kg\nHarga 8500', {'nama': 'Ahmad Sutisna'}, 'titles Bpk. H.'),
  Case('N02', 'Nama: Ibu Hj. Siti Aminah\nBerat 100 kg', {'nama': 'Siti Aminah'}, 'titles Ibu Hj.'),
  Case('N03', 'Nama : Drs. Bambang, S.P.\nBerat 100 kg', {'nama': 'Bambang'}, 'academic titles'),
  Case('N04', "Nama: Ma'ruf Hidayat\nBerat 100 kg", {'nama': "Ma'ruf Hidayat"}, 'apostrophe'),
  Case('N05', 'Nama: Agus Netto\nBerat 100 kg', {'nama': 'Agus Netto'}, 'name contains keyword'),
  Case('N06', 'Petani: Pak Dedi    Berat 200 kg', {'nama': 'Dedi'}, 'column on same line + Pak'),
  Case('N07', 'Nama:\nBudi Santoso\nBerat 100 kg', {'nama': 'Budi Santoso'}, 'name on next line'),
  Case('N08', 'Desa: Cibodas Kec. Lembang\nBerat 100 kg', {'desa': 'Cibodas'}, 'desa + kecamatan'),
  Case('N09', 'Nama: Nur\nDesa: Sukamaju', {'nama': 'Nur', 'desa': 'Sukamaju'}, '3-letter name'),
];

void main() {
  final svc = OcrRegexService();

  group('OCR probe (43 cases)', () {
    for (final c in cases) {
      test('${c.id} ${c.note}', () {
        final r = svc.parseText(c.text);
        c.expect.forEach((k, v) => expect(r[k], v, reason: '${c.id} field "$k" (full: $r)'));
      });
    }
  });

  group('Ambiguous numbers are never used as price', () {
    test('inconsistent separators -> empty price', () {
      expect(svc.parseText('Berat 100 kg\nHarga 8.50.0')['harga'], '');
      expect(svc.parseText('Berat 100 kg\nHarga 1.2500')['harga'], '');
    });

    test('canonicalNumber', () {
      expect(svc.canonicalNumber('1.700.000'), '1700000');
      expect(svc.canonicalNumber('1,250.5'), '1250.5');
      expect(svc.canonicalNumber('1.250,5'), '1250.5');
      expect(svc.canonicalNumber('8.500,00'), '8500');
      expect(svc.canonicalNumber('12,5'), '12.5');
      expect(svc.canonicalNumber('85OO'), '8500');
      expect(svc.canonicalNumber('12.06.2026'), isNull);
      expect(svc.canonicalNumber('1250.000'), isNull);
    });

    test('confusion letters only change numeric tokens', () {
      expect(svc.normalizeNumbers('TBS Sawit Bpk. Ibu'), 'TBS Sawit Bpk. Ibu');
      expect(svc.normalizeNumbers('Total 1.700.000'), 'Total 1700000');
      expect(svc.normalizeNumbers('Rp. 8 500'), 'Rp. 8500');
      expect(svc.normalizeNumbers('Tgl12 berat 2B0kg'), 'Tgl12 berat 280kg');
    });

    test('weight token is not reused as price', () {
      expect(svc.parseText('Berat 1.500 kg')['harga'], '');
    });
  });
}
