/// Jadwal coba ulang sinkronisasi. Murni, tanpa `Timer`, supaya mudah diuji.
class RetryPolicy {
  const RetryPolicy();

  static const List<Duration> _jadwal = [
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 2),
    Duration(minutes: 4),
    Duration(minutes: 8),
    Duration(minutes: 15),
  ];

  /// Sesudah percobaan ini, coba ulang otomatis berhenti sampai ada pemicu baru.
  static int get batas => _jadwal.length + 1;

  static const double _jitter = 0.2;

  /// Tunda sebelum percobaan ke-[percobaan], dihitung dari 1. Null bila sudah
  /// melewati batas.
  ///
  /// [acak] bernilai 0 sampai 1 dan menjadi jitter ±20%, supaya banyak HP yang
  /// kembali online bersamaan tidak menyerbu server pada detik yang sama.
  Duration? tunda(int percobaan, {double acak = 0.5}) {
    if (percobaan < 1 || percobaan >= batas) return null;
    final dasar = _jadwal[percobaan - 1];
    final faktor = 1 - _jitter + (2 * _jitter * acak);
    return Duration(milliseconds: (dasar.inMilliseconds * faktor).round());
  }
}
