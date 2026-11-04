/// Gerbang tipis ke database cloud untuk jalur sinkronisasi.
///
/// Tipe publiknya tidak memakai `mongo_dart`, sehingga mesin sinkronisasi bisa
/// diuji dengan fake di memori tanpa jaringan.
abstract class SyncRemote {
  Future<bool> ping();

  Future<List<Map<String, dynamic>>> find(
    String koleksi,
    Map<String, dynamic> filter, {
    List<String>? fields,
  });

  Future<RemoteWrite> updateOne(
    String koleksi,
    Map<String, dynamic> filter,
    Map<String, dynamic> update, {
    bool upsert = false,
  });

  Future<RemoteWrite> deleteOne(String koleksi, Map<String, dynamic> filter);
}

/// Hasil satu penulisan.
///
/// Bentuknya mengikuti `WriteResult` milik driver: pada upsert yang menyisipkan
/// dokumen baru, [matched] tetap bernilai 1 dan [upserted] juga 1. Jadi dokumen
/// baru hanya bisa dikenali lewat [upserted].
class RemoteWrite {
  /// Kode MongoDB untuk pelanggaran unique index.
  static const int kodeDuplikat = 11000;

  final bool ok;
  final int matched;
  final int modified;
  final int upserted;
  final int removed;
  final int? errorCode;

  const RemoteWrite({
    required this.ok,
    this.matched = 0,
    this.modified = 0,
    this.upserted = 0,
    this.removed = 0,
    this.errorCode,
  });

  /// True hanya bila ada dokumen yang benar-benar kena.
  ///
  /// `ok` saja tidak cukup: server menjawab sukses walau filter tidak cocok
  /// dengan dokumen apa pun.
  bool get kenaDokumen => ok && (matched >= 1 || upserted == 1);

  bool get duplikat => errorCode == kodeDuplikat;

  @override
  String toString() =>
      'RemoteWrite(ok: $ok, matched: $matched, modified: $modified, '
      'upserted: $upserted, removed: $removed, errorCode: $errorCode)';
}
