import '../../models/hive/transaksi_hive_model.dart';
import '../sync/mongo_id.dart';
import 'kasbon_rules.dart';

/// Efek satu transaksi aktif pada saldo.
class EntriSaldo {
  final String petaniId;
  final String pengepulId;
  final double deltaKasbon;
  final double deltaUangJalan;

  const EntriSaldo({
    required this.petaniId,
    required this.pengepulId,
    required this.deltaKasbon,
    required this.deltaUangJalan,
  });

  factory EntriSaldo.dariDokumen(Map<String, dynamic> d) => _buat(
        petaniId: d['petani_id'],
        pengepulId: d['pengepul_id'],
        namaKomoditas: d['nama_komoditas']?.toString() ?? '',
        totalBayar: _angka(d['total_bayar']),
        potongan: _angka(d['nominal_potong_kasbon']),
      );

  factory EntriSaldo.dariBaris(TransaksiHiveModel t) => _buat(
        petaniId: t.petaniId,
        pengepulId: t.pengepulId,
        namaKomoditas: t.namaKomoditas,
        totalBayar: t.totalBayar,
        potongan: t.nominalPotongKasbon,
      );

  static EntriSaldo _buat({
    required Object? petaniId,
    required Object? pengepulId,
    required String namaKomoditas,
    required double totalBayar,
    required double potongan,
  }) {
    final pencairan = KasbonRules.isPencairan(namaKomoditas);
    return EntriSaldo(
      petaniId: MongoId.kanonik(petaniId),
      pengepulId: MongoId.kanonik(pengepulId),
      deltaKasbon: KasbonRules.deltaKasbon(
        pencairan: pencairan,
        totalBayar: totalBayar,
        potongan: potongan,
      ),
      deltaUangJalan: KasbonRules.deltaUangJalan(
        pencairan: pencairan,
        totalBayar: totalBayar,
        potongan: potongan,
      ),
    );
  }

  static double _angka(Object? v) => v is num ? v.toDouble() : 0.0;
}

/// Jumlah delta per petani dan per agen.
class RingkasanSaldo {
  final Map<String, double> _kasbon = {};
  final Map<String, double> _uangJalan = {};

  RingkasanSaldo._(Iterable<EntriSaldo> entri) {
    for (final e in entri) {
      if (e.petaniId.isNotEmpty) {
        _kasbon[e.petaniId] = (_kasbon[e.petaniId] ?? 0) + e.deltaKasbon;
      }
      if (e.pengepulId.isNotEmpty) {
        _uangJalan[e.pengepulId] =
            (_uangJalan[e.pengepulId] ?? 0) + e.deltaUangJalan;
      }
    }
  }

  double deltaKasbon(Object? petaniId) =>
      _kasbon[MongoId.kanonik(petaniId)] ?? 0;

  double deltaUangJalan(Object? pengepulId) =>
      _uangJalan[MongoId.kanonik(pengepulId)] ?? 0;
}

/// Saldo diturunkan dari daftar transaksi: `sisa = saldo_dasar + jumlah delta`.
///
/// Karena dihitung ulang dari nol, retry, crash, dan duplikat tidak bisa
/// menumpuk selisih. Fungsi di sini murni.
class SaldoLedger {
  SaldoLedger._();

  /// Kunci baris Hive untuk satu dokumen transaksi.
  ///
  /// Sengaja bukan [MongoId.kanonik] untuk `_id`: baris lama dari dokumen tanpa
  /// `id_lokal` sudah tersimpan dengan kunci `_id.toString()`, dan `idLokal`
  /// adalah kunci opak.
  static String kunciDokumen(Map<String, dynamic> d) {
    final idLokal = d['id_lokal']?.toString() ?? '';
    return idLokal.isNotEmpty ? idLokal : d['_id'].toString();
  }

  /// Ringkasan dari dokumen cloud, dengan duplikat `id_lokal` dihitung sekali.
  static RingkasanSaldo hitung(Iterable<Map<String, dynamic>> dokumen) =>
      RingkasanSaldo._(_aktif(dokumen).values);

  /// Ringkasan yang dilihat perangkat ini: dokumen cloud, ditimpa baris yang
  /// belum terkirim, dikurangi baris yang menunggu dihapus. Baris lokal dikenali
  /// lewat kuncinya, jadi baris yang sebenarnya sudah sampai ke cloud tidak
  /// terhitung dua kali.
  static RingkasanSaldo efektif(
    Iterable<Map<String, dynamic>> dokumen,
    Iterable<TransaksiHiveModel> barisLokal,
  ) {
    final aktif = _aktif(dokumen);
    for (final t in barisLokal) {
      switch (t.statusSinkronisasi) {
        case 'pending':
        case 'pending_update':
          aktif[t.idLokal] = EntriSaldo.dariBaris(t);
        case 'pending_delete':
          aktif.remove(t.idLokal);
      }
    }
    return RingkasanSaldo._(aktif.values);
  }

  /// Dibulatkan ke dua desimal, supaya galat `double` tidak terlihat di layar
  /// dan tidak menolak pengeluaran yang pas dengan saldo.
  static double saldo(double dasar, double delta) =>
      ((dasar + delta) * 100).round() / 100;

  static Map<String, EntriSaldo> _aktif(
    Iterable<Map<String, dynamic>> dokumen,
  ) {
    final terpilih = <String, Map<String, dynamic>>{};
    for (final d in dokumen) {
      final kunci = kunciDokumen(d);
      final lama = terpilih[kunci];
      if (lama == null || _lebihDiutamakan(d, lama)) terpilih[kunci] = d;
    }
    return terpilih.map((k, d) => MapEntry(k, EntriSaldo.dariDokumen(d)));
  }

  /// Memilih salah satu duplikat tanpa bergantung pada urutan dokumen: yang
  /// terakhir disinkron, karena hanya dokumen itu yang menerima edit.
  static bool _lebihDiutamakan(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final waktu = (a['waktu_disinkron']?.toString() ?? '')
        .compareTo(b['waktu_disinkron']?.toString() ?? '');
    if (waktu != 0) return waktu > 0;
    return MongoId.kanonik(a['_id']).compareTo(MongoId.kanonik(b['_id'])) < 0;
  }
}
