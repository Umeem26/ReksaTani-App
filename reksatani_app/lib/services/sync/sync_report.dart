/// Satu masalah yang ditemukan selama siklus sinkronisasi.
class SyncIssue {
  /// Tahap siklus, misalnya `push_transaksi`.
  final String tahap;

  /// Baris yang bermasalah, bila masalahnya menyangkut satu baris.
  final String? idLokal;

  /// Kode singkat, misalnya `ditolak_server`. Pesan untuk layar diturunkan dari
  /// kode ini, bukan dari exception mentah yang bisa berisi detail server.
  final String jenis;

  final String pesan;

  const SyncIssue({
    required this.tahap,
    this.idLokal,
    required this.jenis,
    required this.pesan,
  });

  @override
  String toString() => 'SyncIssue($tahap, $jenis, idLokal: $idLokal): $pesan';
}

/// Ringkasan satu siklus sinkronisasi.
class SyncReport {
  final List<SyncIssue> masalah;

  /// Jumlah baris yang berhasil sampai ke cloud pada siklus ini.
  final int terkirim;

  /// Jumlah baris riwayat dari cloud yang baru masuk ke perangkat ini.
  final int riwayatBaru;

  final DateTime selesai;

  SyncReport({
    required List<SyncIssue> masalah,
    required this.terkirim,
    this.riwayatBaru = 0,
    required this.selesai,
  }) : masalah = List.unmodifiable(masalah);

  bool get sukses => masalah.isEmpty;
}
