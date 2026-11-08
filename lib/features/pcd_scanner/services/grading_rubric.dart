import 'commodity_mapper.dart';

/// Rubrik grading manual: grade A/B/C ditentukan manusia lewat checklist ini,
/// bukan oleh model. Isinya data; satu-satunya logika adalah [gradeDariJawaban].
///
/// Draf, belum disahkan ahli. Setiap perubahan isi wajib menaikkan [rubrikVersi],
/// karena versi ikut tersimpan di transaksi bersama jawabannya.
const String rubrikVersi = 'v0.1-draf';

/// Rentang persentase sebuah opsi. Batas atas selalu termasuk; batas bawah
/// termasuk hanya bila [termasukDari], supaya opsi bersebelahan tidak tumpang tindih.
class RentangPersen {
  final double dari;
  final double sampai;
  final bool termasukDari;

  const RentangPersen(this.dari, this.sampai, {this.termasukDari = false});

  bool memuat(double persen) =>
      (termasukDari ? persen >= dari : persen > dari) && persen <= sampai;
}

class OpsiRubrik {
  final String kode;
  final String label;

  /// Grade terbaik yang masih mungkin bila opsi ini dipilih.
  final String grade;
  final RentangPersen? rentang;

  const OpsiRubrik(this.kode, this.label, this.grade, {this.rentang});
}

class PertanyaanRubrik {
  final String kode;
  final String teks;
  final List<OpsiRubrik> opsi;

  const PertanyaanRubrik(this.kode, this.teks, this.opsi);

  OpsiRubrik? opsiDenganKode(String? kode) {
    for (final o in opsi) {
      if (o.kode == kode) return o;
    }
    return null;
  }

  /// Opsi yang rentangnya memuat [persen], atau null bila tidak ada.
  OpsiRubrik? opsiUntukPersen(double persen) {
    for (final o in opsi) {
      if (o.rentang?.memuat(persen) ?? false) return o;
    }
    return null;
  }
}

class RubrikKomoditas {
  /// Sama dengan label router ('kelapa_sawit', 'kopi', 'gabah').
  final String kunci;
  final String nama;
  final List<String> catatan;
  final List<PertanyaanRubrik> pertanyaan;

  const RubrikKomoditas({
    required this.kunci,
    required this.nama,
    required this.catatan,
    required this.pertanyaan,
  });
}

const List<RubrikKomoditas> daftarRubrik = [
  RubrikKomoditas(
    kunci: 'kelapa_sawit',
    nama: 'Kelapa Sawit',
    catatan: ['Brondolan dihitung dari buah luar tandan.'],
    pertanyaan: [
      PertanyaanRubrik('brondolan', 'Perkiraan brondolan lepas dari buah luar', [
        OpsiRubrik('nol', 'Tidak ada brondolan', 'C',
            rentang: RentangPersen(0, 0, termasukDari: true)),
        OpsiRubrik('sd12_5', 'Sedikit, sampai 12,5%', 'C', rentang: RentangPersen(0, 12.5)),
        OpsiRubrik('12_5-25', 'Di atas 12,5% sampai 25%', 'B', rentang: RentangPersen(12.5, 25)),
        OpsiRubrik('25-75', 'Di atas 25% sampai 75%', 'A', rentang: RentangPersen(25, 75)),
        OpsiRubrik('75-100', 'Di atas 75% sampai 100%', 'B', rentang: RentangPersen(75, 100)),
      ]),
      PertanyaanRubrik('buah_dalam', 'Ada buah dalam ikut lepas, atau tandan kosong?', [
        OpsiRubrik('tidak', 'Tidak', 'A'),
        OpsiRubrik('ya', 'Ya', 'C'),
      ]),
    ],
  ),
  RubrikKomoditas(
    kunci: 'kopi',
    nama: 'Kopi',
    catatan: [
      'Estimasi visual, bukan nilai cacat SNI.',
      'Ambang ini perkiraan, belum divalidasi.',
    ],
    pertanyaan: [
      PertanyaanRubrik(
        'biji_cacat',
        'Perkiraan biji cacat (hitam, pecah, berlubang, kulit tanduk, kotoran)',
        [
          OpsiRubrik('sd10', 'Sekitar 10% atau kurang', 'A',
              rentang: RentangPersen(0, 10, termasukDari: true)),
          OpsiRubrik('10-30', 'Di atas 10% sampai 30%', 'B', rentang: RentangPersen(10, 30)),
          OpsiRubrik('di_atas30', 'Di atas 30%', 'C', rentang: RentangPersen(30, 100)),
        ],
      ),
    ],
  ),
  RubrikKomoditas(
    kunci: 'gabah',
    nama: 'Gabah',
    catatan: ['Kadar air tidak terlihat dari foto dan tidak dinilai di sini.'],
    pertanyaan: [
      PertanyaanRubrik('kotoran_hampa', 'Perkiraan kotoran dan gabah hampa', [
        OpsiRubrik('sd3', '3% atau kurang', 'A',
            rentang: RentangPersen(0, 3, termasukDari: true)),
        OpsiRubrik('3-10', 'Di atas 3% sampai 10%', 'B', rentang: RentangPersen(3, 10)),
        OpsiRubrik('di_atas10', 'Di atas 10%', 'C', rentang: RentangPersen(10, 100)),
      ]),
      PertanyaanRubrik('butir', 'Kondisi butir', [
        OpsiRubrik('seragam', 'Seragam, hampir tanpa butir rusak', 'A'),
        OpsiRubrik('kurang_seragam', 'Kurang seragam', 'B'),
        OpsiRubrik('banyak_rusak', 'Banyak butir rusak', 'C'),
      ]),
    ],
  ),
];

/// Rubrik untuk label router ('kelapa_sawit', 'kopi', 'gabah'), atau null.
RubrikKomoditas? rubrikUntukLabel(String? label) {
  for (final r in daftarRubrik) {
    if (r.kunci == label) return r;
  }
  return null;
}

/// Rubrik untuk nama komoditas master data ("Sawit", "Kopi Robusta", "Gabah"),
/// memakai pencocokan yang sama dengan [CommodityMapper].
RubrikKomoditas? rubrikUntukKomoditas(String? namaKomoditas) {
  if (namaKomoditas == null || namaKomoditas.trim().isEmpty) return null;
  for (final r in daftarRubrik) {
    if (CommodityMapper.match<String>([namaKomoditas], (s) => s, r.kunci) != null) return r;
  }
  return null;
}

const List<String> _urutanGrade = ['A', 'B', 'C'];

/// Grade dari jawaban checklist: grade terburuk di antara opsi yang dipilih.
///
/// Null bila ada pertanyaan yang belum dijawab atau jawabannya tidak dikenal,
/// sehingga grade tidak pernah muncul dari checklist yang belum lengkap.
String? gradeDariJawaban(RubrikKomoditas rubrik, Map<String, String> jawaban) {
  var terburuk = 0;
  for (final p in rubrik.pertanyaan) {
    final opsi = p.opsiDenganKode(jawaban[p.kode]);
    if (opsi == null) return null;
    final i = _urutanGrade.indexOf(opsi.grade);
    if (i > terburuk) terburuk = i;
  }
  return _urutanGrade[terburuk];
}

/// Jawaban sebagai `pertanyaan=opsi`, urut seperti pertanyaan di rubrik.
List<String> kodekanJawaban(RubrikKomoditas rubrik, Map<String, String> jawaban) => [
      for (final p in rubrik.pertanyaan)
        if (jawaban[p.kode] != null) '${p.kode}=${jawaban[p.kode]}',
    ];

/// Kebalikan [kodekanJawaban]. Entri tanpa `=` dilewati.
Map<String, String> bacaJawaban(List<String>? kode) {
  final hasil = <String, String>{};
  for (final k in kode ?? const <String>[]) {
    final i = k.indexOf('=');
    if (i <= 0) continue;
    hasil[k.substring(0, i)] = k.substring(i + 1);
  }
  return hasil;
}
