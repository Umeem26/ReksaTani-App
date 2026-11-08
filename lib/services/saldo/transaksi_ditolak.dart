/// Aturan uang menolak sebuah perubahan. [pesan] siap ditampilkan ke pengguna.
class TransaksiDitolak implements Exception {
  final String kode;
  final String pesan;

  const TransaksiDitolak(this.kode, this.pesan);

  @override
  String toString() => 'TransaksiDitolak($kode)';
}
