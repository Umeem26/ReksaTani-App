import 'package:flutter_test/flutter_test.dart';
import 'package:reksatani_app/features/pcd_scanner/services/grading_rubric.dart';

RubrikKomoditas _r(String kunci) => rubrikUntukLabel(kunci)!;

String? _gradeUntukPersen(String kunci, String pertanyaan, double persen) {
  final p = _r(kunci).pertanyaan.firstWhere((q) => q.kode == pertanyaan);
  return p.opsiUntukPersen(persen)?.grade;
}

void main() {
  test('versi rubrik tercatat sebagai draf', () {
    expect(rubrikVersi, 'v0.1-draf');
  });

  group('data rubrik', () {
    test('setiap komoditas router punya rubrik', () {
      expect(daftarRubrik.map((r) => r.kunci), ['kelapa_sawit', 'kopi', 'gabah']);
    });

    test('kode pertanyaan dan opsi unik, grade hanya A/B/C, tanpa "=" di kode', () {
      for (final r in daftarRubrik) {
        final kodeP = r.pertanyaan.map((p) => p.kode).toList();
        expect(kodeP.toSet().length, kodeP.length, reason: r.kunci);
        for (final p in r.pertanyaan) {
          expect(p.kode.contains('='), isFalse);
          final kodeO = p.opsi.map((o) => o.kode).toList();
          expect(kodeO.toSet().length, kodeO.length, reason: p.kode);
          for (final o in p.opsi) {
            expect(['A', 'B', 'C'], contains(o.grade), reason: o.kode);
          }
        }
      }
    });

    test('rentang persentase menutup 0..100 tanpa celah dan tanpa tumpang tindih', () {
      for (final r in daftarRubrik) {
        for (final p in r.pertanyaan.where((p) => p.opsi.any((o) => o.rentang != null))) {
          for (var x = 0.0; x <= 100.0; x += 0.25) {
            final cocok = p.opsi.where((o) => o.rentang!.memuat(x)).length;
            expect(cocok, 1, reason: '${r.kunci}/${p.kode} pada $x%');
          }
          expect(p.opsiUntukPersen(-0.01), isNull);
          expect(p.opsiUntukPersen(100.01), isNull);
        }
      }
    });
  });

  group('ambang kelapa sawit (brondolan)', () {
    final cases = <double, String>{
      0: 'C', // tanpa brondol
      0.01: 'C',
      12.5: 'C',
      12.51: 'B',
      25: 'B',
      25.01: 'A',
      75: 'A',
      75.01: 'B',
      100: 'B',
    };
    cases.forEach((persen, grade) {
      test('$persen% -> $grade', () {
        expect(_gradeUntukPersen('kelapa_sawit', 'brondolan', persen), grade);
      });
    });

    test('buah dalam ikut lepas atau tandan kosong selalu C', () {
      for (final b in _r('kelapa_sawit').pertanyaan.first.opsi) {
        expect(
          gradeDariJawaban(_r('kelapa_sawit'), {'brondolan': b.kode, 'buah_dalam': 'ya'}),
          'C',
          reason: b.kode,
        );
      }
    });

    test('25-75% tanpa buah dalam -> A', () {
      expect(gradeDariJawaban(_r('kelapa_sawit'), {'brondolan': '25-75', 'buah_dalam': 'tidak'}), 'A');
    });
  });

  group('ambang kopi (biji cacat, perkiraan)', () {
    final cases = <double, String>{0: 'A', 10: 'A', 10.01: 'B', 30: 'B', 30.01: 'C', 100: 'C'};
    cases.forEach((persen, grade) {
      test('$persen% -> $grade', () {
        expect(_gradeUntukPersen('kopi', 'biji_cacat', persen), grade);
      });
    });

    test('catatan menandai ambang belum divalidasi dan bukan SNI', () {
      final catatan = _r('kopi').catatan.join(' ');
      expect(catatan, contains('belum divalidasi'));
      expect(catatan, contains('bukan nilai cacat SNI'));
    });
  });

  group('ambang gabah', () {
    final cases = <double, String>{0: 'A', 3: 'A', 3.01: 'B', 10: 'B', 10.01: 'C', 100: 'C'};
    cases.forEach((persen, grade) {
      test('kotoran/hampa $persen% -> $grade', () {
        expect(_gradeUntukPersen('gabah', 'kotoran_hampa', persen), grade);
      });
    });

    test('A butuh kotoran <= 3% dan butir seragam', () {
      final g = _r('gabah');
      expect(gradeDariJawaban(g, {'kotoran_hampa': 'sd3', 'butir': 'seragam'}), 'A');
      expect(gradeDariJawaban(g, {'kotoran_hampa': 'sd3', 'butir': 'kurang_seragam'}), 'B');
      expect(gradeDariJawaban(g, {'kotoran_hampa': '3-10', 'butir': 'seragam'}), 'B');
    });

    test('banyak butir rusak atau kotoran > 10% -> C', () {
      final g = _r('gabah');
      expect(gradeDariJawaban(g, {'kotoran_hampa': 'sd3', 'butir': 'banyak_rusak'}), 'C');
      expect(gradeDariJawaban(g, {'kotoran_hampa': 'di_atas10', 'butir': 'seragam'}), 'C');
    });

    test('catatan menyebut kadar air tidak dinilai', () {
      expect(_r('gabah').catatan.join(' '), contains('Kadar air'));
    });
  });

  group('gradeDariJawaban: kasus tepi', () {
    test('checklist kosong atau belum lengkap -> null', () {
      expect(gradeDariJawaban(_r('gabah'), {}), isNull);
      expect(gradeDariJawaban(_r('gabah'), {'kotoran_hampa': 'sd3'}), isNull);
    });

    test('kode opsi tidak dikenal -> null, bukan grade terbaik', () {
      expect(gradeDariJawaban(_r('kopi'), {'biji_cacat': 'ngawur'}), isNull);
    });

    test('jawaban berlebih dari pertanyaan lain diabaikan', () {
      expect(gradeDariJawaban(_r('kopi'), {'biji_cacat': 'sd10', 'butir': 'banyak_rusak'}), 'A');
    });
  });

  group('pemetaan nama master data', () {
    test('nama master data dipetakan ke rubrik yang benar', () {
      expect(rubrikUntukKomoditas('Sawit')?.kunci, 'kelapa_sawit');
      expect(rubrikUntukKomoditas('Kopi Robusta')?.kunci, 'kopi');
      expect(rubrikUntukKomoditas('Gabah')?.kunci, 'gabah');
      expect(rubrikUntukKomoditas('gabah kering giling')?.kunci, 'gabah');
    });

    test('nama tidak dikenal, kosong, atau null -> null', () {
      expect(rubrikUntukKomoditas('Jagung'), isNull);
      expect(rubrikUntukKomoditas(''), isNull);
      expect(rubrikUntukKomoditas(null), isNull);
      expect(rubrikUntukLabel('bukan_komoditas'), isNull);
    });
  });

  group('kode jawaban', () {
    test('bolak-balik kodekan dan baca', () {
      final r = _r('kelapa_sawit');
      final jawaban = {'buah_dalam': 'tidak', 'brondolan': '12_5-25'};
      final kode = kodekanJawaban(r, jawaban);

      expect(kode, ['brondolan=12_5-25', 'buah_dalam=tidak']);
      expect(bacaJawaban(kode), jawaban);
    });

    test('pertanyaan yang belum dijawab tidak ikut dikodekan', () {
      expect(kodekanJawaban(_r('gabah'), {'butir': 'seragam'}), ['butir=seragam']);
    });

    test('null, kosong, dan entri rusak dibaca aman', () {
      expect(bacaJawaban(null), isEmpty);
      expect(bacaJawaban(const []), isEmpty);
      expect(bacaJawaban(const ['tanpa_sama_dengan', '=x', 'a=b']), {'a': 'b'});
    });
  });
}
