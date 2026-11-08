import 'package:reksatani_app/services/sync/sync_remote.dart';

const String dasarKasbon = 'saldo_dasar_kasbon';
const String sisaKasbon = 'sisa_hutang_kasbon';
const String dasarUangJalan = 'saldo_dasar_uang_jalan';
const String sisaUangJalan = 'sisa_uang_jalan';

const Map<String, dynamic> filterAgen = {'role': 'pengepul'};

typedef Cetak = void Function(String baris);

/// Opsi baris perintah. Semua skrip di sini hanya menulis bila [konfirmasi] true.
class OpsiCli {
  final bool konfirmasi;
  final double? kasbon;
  final double? uangJalan;

  const OpsiCli({this.konfirmasi = false, this.kasbon, this.uangJalan});

  /// Melempar [FormatException] untuk flag yang tidak dikenal, supaya salah ketik
  /// tidak terbaca sebagai perintah lain.
  factory OpsiCli.parse(List<String> args, {bool izinkanNilai = false}) {
    var konfirmasi = false;
    double? kasbon;
    double? uangJalan;

    double angka(String arg) {
      final nilai = double.tryParse(arg.split('=').last);
      if (nilai == null || nilai < 0) {
        throw FormatException('Nilai tidak sah: $arg');
      }
      return nilai;
    }

    for (final arg in args) {
      if (arg == '--confirm') {
        konfirmasi = true;
      } else if (izinkanNilai && arg.startsWith('--kasbon=')) {
        kasbon = angka(arg);
      } else if (izinkanNilai && arg.startsWith('--uang-jalan=')) {
        uangJalan = angka(arg);
      } else {
        throw FormatException('Flag tidak dikenal: $arg');
      }
    }
    return OpsiCli(konfirmasi: konfirmasi, kasbon: kasbon, uangJalan: uangJalan);
  }
}

/// Mengembalikan data uji ke keadaan tanpa transaksi.
///
/// Akun, petani, dan komoditas tetap ada. Semua transaksi dihapus, lalu saldo
/// setiap petani dan agen diatur ulang sehingga `sisa == saldo_dasar`. Nilainya,
/// berurutan: opsi eksplisit, saldo dasar yang sudah ada, atau sisa sekarang.
///
/// Aman diulang bila terhenti di tengah. Tanpa [konfirmasi], tidak menulis apa pun.
Future<void> resetDataUji(
  SyncRemote remote,
  OpsiCli opsi, {
  required Cetak cetak,
}) async {
  final transaksi = await remote.find('transaksi', {}, fields: const ['_id']);
  final petani = await remote.find(
    'petani',
    {},
    fields: const [dasarKasbon, sisaKasbon],
  );
  final agen = await remote.find(
    'users',
    filterAgen,
    fields: const [dasarUangJalan, sisaUangJalan],
  );

  cetak('Transaksi yang akan dihapus : ${transaksi.length}');
  cetak('Petani yang saldonya diatur : ${petani.length}');
  cetak('Agen yang saldonya diatur   : ${agen.length}');

  if (!opsi.konfirmasi) {
    cetak('DRY-RUN: tidak ada yang ditulis. Tambahkan --confirm untuk menjalankan.');
    return;
  }

  var gagal = 0;
  for (final d in transaksi) {
    final hasil = await remote.deleteOne('transaksi', {'_id': d['_id']});
    if (!hasil.ok) gagal++;
  }

  Future<void> aturSaldo(
    String koleksi,
    Map<String, dynamic> d,
    String fieldDasar,
    String fieldSisa,
    double? paksa,
  ) async {
    final nilai = paksa ?? _angka(d[fieldDasar]) ?? _angka(d[fieldSisa]) ?? 0.0;
    final hasil = await remote.updateOne(koleksi, {'_id': d['_id']}, {
      r'$set': {fieldDasar: nilai, fieldSisa: nilai},
    });
    if (!hasil.kenaDokumen) gagal++;
  }

  for (final d in petani) {
    await aturSaldo('petani', d, dasarKasbon, sisaKasbon, opsi.kasbon);
  }
  for (final d in agen) {
    await aturSaldo('users', d, dasarUangJalan, sisaUangJalan, opsi.uangJalan);
  }

  cetak(gagal == 0
      ? 'Selesai.'
      : 'Selesai dengan $gagal kegagalan. Jalankan ulang skrip ini.');
  if (gagal > 0) throw StateError('$gagal penulisan gagal');
}

/// Mengisi `saldo_dasar_* = sisa_*` untuk dokumen yang belum punya field itu.
///
/// Idempoten: dokumen yang sudah punya field tidak disentuh.
Future<void> isiSaldoDasar(
  SyncRemote remote,
  OpsiCli opsi, {
  required Cetak cetak,
}) async {
  final jumlahTransaksi =
      (await remote.find('transaksi', {}, fields: const ['_id'])).length;
  final petani = await remote.find(
    'petani',
    {
      dasarKasbon: {r'$exists': false},
    },
    fields: const [sisaKasbon],
  );
  final agen = await remote.find(
    'users',
    {
      ...filterAgen,
      dasarUangJalan: {r'$exists': false},
    },
    fields: const [sisaUangJalan],
  );

  cetak('Petani tanpa saldo dasar : ${petani.length}');
  cetak('Agen tanpa saldo dasar   : ${agen.length}');
  if (jumlahTransaksi > 0 && (petani.isNotEmpty || agen.isNotEmpty)) {
    cetak('PERINGATAN: masih ada $jumlahTransaksi transaksi. Efeknya akan terhitung '
        'lagi di atas saldo dasar ini. Jalankan reset_data_uji.dart lebih dulu.');
  }

  if (!opsi.konfirmasi) {
    cetak('DRY-RUN: tidak ada yang ditulis. Tambahkan --confirm untuk menjalankan.');
    return;
  }

  var gagal = 0;
  Future<void> isi(
    String koleksi,
    Map<String, dynamic> d,
    String fieldDasar,
    String fieldSisa,
  ) async {
    final nilai = _angka(d[fieldSisa]);
    final hasil = await remote.updateOne(
      koleksi,
      {
        '_id': d['_id'],
        fieldDasar: {r'$exists': false},
      },
      {
        r'$set': {
          fieldDasar: nilai ?? 0.0,
          if (nilai == null) fieldSisa: 0.0,
        },
      },
    );
    if (!hasil.ok) gagal++;
  }

  for (final d in petani) {
    await isi('petani', d, dasarKasbon, sisaKasbon);
  }
  for (final d in agen) {
    await isi('users', d, dasarUangJalan, sisaUangJalan);
  }

  cetak(gagal == 0
      ? 'Selesai.'
      : 'Selesai dengan $gagal kegagalan. Jalankan ulang skrip ini.');
  if (gagal > 0) throw StateError('$gagal penulisan gagal');
}

double? _angka(Object? v) => v is num ? v.toDouble() : null;

/// Satu index yang dibutuhkan sinkronisasi.
class SpekIndex {
  final String nama;
  final Map<String, int> kunci;
  final bool unik;
  final Map<String, dynamic>? parsial;

  const SpekIndex({
    required this.nama,
    required this.kunci,
    this.unik = false,
    this.parsial,
  });
}

const List<SpekIndex> indexTransaksi = [
  SpekIndex(
    nama: 'uniq_id_lokal',
    kunci: {'id_lokal': 1},
    unik: true,
    parsial: {
      'id_lokal': {r'$type': 'string'},
    },
  ),
  SpekIndex(nama: 'idx_petani_id', kunci: {'petani_id': 1}),
  SpekIndex(nama: 'idx_pengepul_id', kunci: {'pengepul_id': 1}),
];

class IndexDilewati {
  final SpekIndex spek;
  final String namaAda;

  const IndexDilewati(this.spek, this.namaAda);
}

class RencanaIndex {
  final List<SpekIndex> dibuat;
  final List<IndexDilewati> dilewati;

  /// Index berkunci sama sudah ada, tetapi tidak memenuhi `unik`.
  final List<IndexDilewati> konflik;

  const RencanaIndex({
    required this.dibuat,
    required this.dilewati,
    required this.konflik,
  });
}

/// Membandingkan [spek] dengan balasan `listIndexes`. Index berkunci sama dilewati,
/// apa pun namanya: server menolak membuat yang kedua dengan kode 85.
///
/// Urutan field ikut menentukan: `{a: 1, b: 1}` bukan index yang sama dengan
/// `{b: 1, a: 1}`, dan index gabungan `{pengepul_id: 1, status: 1}` tidak dianggap
/// sama dengan `{pengepul_id: 1}`.
RencanaIndex rencanaIndex(
  List<Map<String, dynamic>> ada, {
  List<SpekIndex> spek = indexTransaksi,
}) {
  final dibuat = <SpekIndex>[];
  final dilewati = <IndexDilewati>[];
  final konflik = <IndexDilewati>[];

  for (final s in spek) {
    final sama = ada.where((i) => _kunciSama(i['key'], s.kunci)).toList();
    if (sama.isEmpty) {
      dibuat.add(s);
      continue;
    }
    final cocok = sama.where((i) => !s.unik || i['unique'] == true);
    if (cocok.isEmpty) {
      konflik.add(IndexDilewati(s, '${sama.first['name']}'));
    } else {
      dilewati.add(IndexDilewati(s, '${cocok.first['name']}'));
    }
  }

  return RencanaIndex(dibuat: dibuat, dilewati: dilewati, konflik: konflik);
}

bool _kunciSama(Object? ada, Map<String, int> kunci) {
  if (ada is! Map || ada.length != kunci.length) return false;
  final namaAda = ada.keys.toList();
  final nama = kunci.keys.toList();
  for (var i = 0; i < nama.length; i++) {
    if (namaAda[i] != nama[i] || ada[nama[i]] != kunci[nama[i]]) return false;
  }
  return true;
}

const String folderSkema = 'tool/atlas/skema';
const List<String> koleksiSkema = ['komoditas', 'petani', 'transaksi', 'users'];

/// Grade pencairan kasbon. Pencairan bukan pembelian, jadi tidak punya grade.
const String gradeTanpaKualitas = '-';

/// Validator satu koleksi dari balasan `listCollections`.
Map<String, dynamic> skemaDariInfo(
  List<Map<String, dynamic>> infos,
  String koleksi,
) {
  final info = infos.where((i) => i['name'] == koleksi);
  if (info.isEmpty) throw StateError('Koleksi tidak ada: $koleksi');
  final opsi = info.first['options'];
  if (opsi is! Map) throw StateError('Koleksi tanpa opsi: $koleksi');
  return {
    'koleksi': koleksi,
    'validator': opsi['validator'],
    'validationLevel': opsi['validationLevel'],
    'validationAction': opsi['validationAction'],
  };
}

/// Salinan [validator] `transaksi` dengan [gradeTanpaKualitas] di enum
/// `grade_terpilih`. Bagian lain tidak berubah, dan yang sudah memuatnya tetap sama.
Map<String, dynamic> tambahGradeTanpaKualitas(Map<String, dynamic> validator) {
  final salinan = _salinDalam(validator) as Map<String, dynamic>;
  final skema = salinan[r'$jsonSchema'];
  final properti = skema is Map ? skema['properties'] : null;
  final grade = properti is Map ? properti['grade_terpilih'] : null;
  final daftar = grade is Map ? grade['enum'] : null;
  if (daftar is! List) {
    throw StateError('Validator tidak punya enum grade_terpilih.');
  }
  if (!daftar.contains(gradeTanpaKualitas)) daftar.add(gradeTanpaKualitas);
  return salinan;
}

/// Nilai bawaan MongoDB bila opsi validasi tidak tercantum. Atlas UI menuliskannya
/// secara eksplisit saat menyimpan validator (diterima Umem 2026-11-08).
const Map<String, String> bawaanValidasi = {
  'validationLevel': 'strict',
  'validationAction': 'error',
};

/// Salinan [skema] (hasil [skemaDariInfo]) dengan opsi validasi yang kosong diisi
/// [bawaanValidasi], supaya `null` dan bawaannya terbaca sama.
Map<String, dynamic> isiBawaanValidasi(Map<String, dynamic> skema) {
  final salinan = _salinDalam(skema) as Map<String, dynamic>;
  bawaanValidasi.forEach((kunci, bawaan) {
    if (salinan.containsKey(kunci)) salinan[kunci] ??= bawaan;
  });
  return salinan;
}

/// Perbedaan [sesudah] dari [sebelum] (keduanya hasil [skemaDariInfo]) selain satu
/// [gradeTanpaKualitas] di enum `grade_terpilih`, di posisi mana pun. Kosong berarti
/// hanya grade itu yang ditambahkan. Enum tanpa grade itu juga dilaporkan.
/// `validationLevel` dan `validationAction` yang kosong setara dengan
/// [bawaanValidasi].
List<String> bedaSelainGradeTanpaKualitas(
  Map<String, dynamic> sebelum,
  Map<String, dynamic> sesudah,
) {
  const lokasi = r'$.validator.$jsonSchema.properties.grade_terpilih.enum';
  sebelum = isiBawaanValidasi(sebelum);
  final salinan = isiBawaanValidasi(sesudah);
  final validator = salinan['validator'];
  final skema = validator is Map ? validator[r'$jsonSchema'] : null;
  final properti = skema is Map ? skema['properties'] : null;
  final grade = properti is Map ? properti['grade_terpilih'] : null;
  final daftar = grade is Map ? grade['enum'] : null;
  if (daftar is! List || !daftar.remove(gradeTanpaKualitas)) {
    return ['$lokasi: tidak memuat "$gradeTanpaKualitas"'];
  }
  return bedaSkema(sebelum, salinan);
}

/// Lokasi perbedaan dua nilai JSON. Urutan kunci dan jenis angka ikut dihitung.
List<String> bedaSkema(Object? a, Object? b, [String lokasi = r'$']) {
  if (a is Map && b is Map) {
    final kunciA = a.keys.toList();
    final kunciB = b.keys.toList();
    if ('$kunciA' != '$kunciB') {
      return ['$lokasi: kunci $kunciA menjadi $kunciB'];
    }
    return [
      for (final k in kunciA) ...bedaSkema(a[k], b[k], '$lokasi.$k'),
    ];
  }
  if (a is List && b is List) {
    if (a.length != b.length) return ['$lokasi: $a menjadi $b'];
    return [
      for (var i = 0; i < a.length; i++) ...bedaSkema(a[i], b[i], '$lokasi[$i]'),
    ];
  }
  if (a.runtimeType != b.runtimeType || a != b) {
    return ['$lokasi: $a menjadi $b'];
  }
  return const [];
}

Object? _salinDalam(Object? v) {
  if (v is Map) {
    return <String, dynamic>{
      for (final e in v.entries) '${e.key}': _salinDalam(e.value),
    };
  }
  if (v is List) return <dynamic>[for (final x in v) _salinDalam(x)];
  return v;
}
