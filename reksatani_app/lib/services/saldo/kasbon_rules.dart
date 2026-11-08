import 'dart:math' as math;

/// Satu sumber rumus kasbon dan uang jalan. Murni: tanpa Hive, Flutter, atau
/// jaringan.
///
/// Efek satu transaksi pada saldo:
///
/// | Jenis     | Kasbon petani | Uang jalan agen      |
/// |-----------|---------------|----------------------|
/// | Pembelian | `-potongan`   | `-(total - potongan)`|
/// | Pencairan | `+total`      | `-total`             |
class KasbonRules {
  KasbonRules._();

  /// Label `nama_komoditas` pada pencairan. Satu-satunya penanda jenis transaksi.
  static const String labelPencairan = 'Pencairan Kasbon Baru';

  /// Seluruh kasbon dipotong sampai batas total bayar, dan tidak pernah negatif.
  static double potongan({
    required double sisaKasbon,
    required double totalBayar,
  }) =>
      math.max(0.0, math.min(sisaKasbon, totalBayar));

  static double tunaiKeluar({
    required double totalBayar,
    required double potongan,
  }) =>
      totalBayar - potongan;

  static bool isPencairan(String namaKomoditas) =>
      namaKomoditas.toLowerCase().contains('pencairan kasbon');

  static double deltaKasbon({
    required bool pencairan,
    required double totalBayar,
    required double potongan,
  }) =>
      pencairan ? totalBayar : -potongan;

  static double deltaUangJalan({
    required bool pencairan,
    required double totalBayar,
    required double potongan,
  }) =>
      pencairan
          ? -totalBayar
          : -tunaiKeluar(totalBayar: totalBayar, potongan: potongan);

  /// Efek mengedit pembelian. Potongan selalu dihitung ulang otomatis.
  ///
  /// [kasbonPetaniLama] dan [kasbonPetaniBaru] null bila petaninya tidak ada.
  /// Pada edit tanpa ganti petani, keduanya bernilai sama dan hasilnya ada di
  /// [EfekEdit.kasbonPetaniBaru].
  static EfekEdit hitungEdit({
    required double totalLama,
    required double potonganLama,
    required double totalBaru,
    required double uangJalan,
    required bool petaniSama,
    double? kasbonPetaniLama,
    double? kasbonPetaniBaru,
  }) {
    final kasbonLamaKembali =
        kasbonPetaniLama == null ? null : kasbonPetaniLama + potonganLama;
    final tersedia = petaniSama ? kasbonLamaKembali : kasbonPetaniBaru;
    final potonganBaru = tersedia == null
        ? 0.0
        : potongan(sisaKasbon: tersedia, totalBayar: totalBaru);

    return EfekEdit(
      potonganBaru: potonganBaru,
      kasbonPetaniLama: petaniSama ? null : kasbonLamaKembali,
      kasbonPetaniBaru: tersedia == null ? null : tersedia - potonganBaru,
      uangJalan: uangJalan +
          tunaiKeluar(totalBayar: totalLama, potongan: potonganLama) -
          tunaiKeluar(totalBayar: totalBaru, potongan: potonganBaru),
    );
  }
}

/// Keadaan saldo sesudah sebuah edit.
class EfekEdit {
  final double potonganBaru;

  /// Null bila tidak ada petani lain yang harus dikembalikan.
  final double? kasbonPetaniLama;

  /// Null bila transaksi tidak lagi punya petani.
  final double? kasbonPetaniBaru;

  final double uangJalan;

  const EfekEdit({
    required this.potonganBaru,
    required this.kasbonPetaniLama,
    required this.kasbonPetaniBaru,
    required this.uangJalan,
  });
}
