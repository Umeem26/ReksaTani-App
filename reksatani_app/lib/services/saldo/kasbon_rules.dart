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
}
