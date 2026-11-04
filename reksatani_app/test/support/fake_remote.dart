import 'package:mongo_dart/mongo_dart.dart' show ObjectId;
import 'package:reksatani_app/services/sync/sync_remote.dart';

/// Exception yang disuntikkan, mewakili socket putus atau balasan yang hilang.
class RemoteGagal implements Exception {
  final String op;
  final bool sesudahDiterapkan;

  RemoteGagal(this.op, {required this.sesudahDiterapkan});

  @override
  String toString() =>
      'RemoteGagal($op, sesudahDiterapkan: $sesudahDiterapkan)';
}

class _Injeksi {
  final String op;
  final String? koleksi;
  final bool sesudah;
  int sisa;

  _Injeksi(this.op, this.koleksi, this.sesudah, this.sisa);
}

/// Satu panggilan yang tercatat, untuk ditegaskan di tes.
class PanggilanRemote {
  final String op;
  final String koleksi;
  final Map<String, dynamic> filter;
  final Map<String, dynamic>? update;
  final bool upsert;

  PanggilanRemote(this.op, this.koleksi, this.filter, this.update, this.upsert);
}

/// Pengganti Atlas di memori.
///
/// Sifat penting yang sengaja ditiru dari server:
/// - Peka tipe: `ObjectId` tidak sama dengan `String`, sehingga bug filter `_id`
///   benar-benar muncul di tes. Literal `ObjectId("...")` juga sekadar string.
/// - Filter yang tidak cocok tetap menjawab `ok: true, matched: 0`.
/// - Upsert hanya menyalin kesetaraan dari filter ke dokumen baru, dan `$in`
///   berisi lebih dari satu nilai tidak ikut tersalin.
/// - Balasan upsert baru berbentuk `matched: 1, upserted: 1`.
/// - Field yang sama di dua operator ditolak dengan kode 40, tanpa exception.
///
/// Operator yang tidak dikenal melempar [UnsupportedError], supaya tes tidak
/// lulus karena filter diam-diam diabaikan.
///
/// Ini tetap fake. Lulus di sini bukan bukti perilaku Atlas.
class FakeRemote implements SyncRemote {
  final Map<String, List<Map<String, dynamic>>> _data = {};
  final Map<String, Set<String>> _unik = {};
  final List<_Injeksi> _injeksi = [];
  final Map<String, List<Map<String, dynamic>>> _sisipanBalapan = {};
  final Map<String, List<int>> _tolakan = {};

  /// Semua panggilan, berurutan.
  final List<PanggilanRemote> panggilan = [];

  bool online = true;

  /// Dijalankan sekali, setelah tulisan berikutnya diterapkan dan sebelum balasan
  /// sampai ke klien. Untuk mensimulasikan agen yang mengedit selama sync berjalan.
  Future<void> Function()? saatMenungguBalasan;

  // ── Pengaturan tes ──────────────────────────────────────────────

  /// Menanam dokumen apa adanya, tanpa memeriksa unique index, seperti data lama.
  void tanam(String koleksi, Map<String, dynamic> dokumen) {
    final salinan = _salin(dokumen);
    salinan.putIfAbsent('_id', ObjectId.new);
    _koleksi(koleksi).add(salinan);
  }

  List<Map<String, dynamic>> dokumen(String koleksi) =>
      _koleksi(koleksi).map(_salin).toList();

  /// Unique index parsial: hanya berlaku pada nilai string, seperti `uniq_id_lokal`.
  void buatIndexUnik(String koleksi, String field) =>
      _unik.putIfAbsent(koleksi, () => {}).add(field);

  /// [n] panggilan [op] berikutnya gagal sebelum diterapkan.
  void gagalSebelum(String op, int n, {String? koleksi}) =>
      _injeksi.add(_Injeksi(op, koleksi, false, n));

  /// [n] panggilan [op] berikutnya diterapkan, lalu klien menerima exception.
  /// Ini mensimulasikan aplikasi mati atau balasan yang hilang.
  void gagalSesudah(String op, int n, {String? koleksi}) =>
      _injeksi.add(_Injeksi(op, koleksi, true, n));

  /// Tulisan berikutnya ke [koleksi] ditolak server: tidak diterapkan, tanpa
  /// exception, dengan `ok: false` dan [kode].
  void tolakBerikutnya(String koleksi, int kode) =>
      _tolakan.putIfAbsent(koleksi, () => []).add(kode);

  /// Mensimulasikan balapan dua upsert: pada upsert berikutnya ke [koleksi],
  /// [dokumen] milik perangkat lain masuk tepat setelah filter tidak menemukan
  /// apa pun dan sebelum penyisipan.
  void balapanUpsert(String koleksi, Map<String, dynamic> dokumen) =>
      _sisipanBalapan.putIfAbsent(koleksi, () => []).add(_salin(dokumen));

  Iterable<PanggilanRemote> panggilanTulis(String koleksi) =>
      panggilan.where((p) => p.koleksi == koleksi && p.update != null);

  // ── SyncRemote ──────────────────────────────────────────────────

  @override
  Future<bool> ping() async {
    final injeksi = _ambilInjeksi('ping', '');
    if (injeksi != null) throw RemoteGagal('ping', sesudahDiterapkan: false);
    return online;
  }

  @override
  Future<List<Map<String, dynamic>>> find(
    String koleksi,
    Map<String, dynamic> filter, {
    List<String>? fields,
  }) async {
    panggilan.add(PanggilanRemote('find', koleksi, filter, null, false));
    _pastikanOnline('find');
    final injeksi = _ambilInjeksi('find', koleksi);
    if (injeksi != null) throw RemoteGagal('find', sesudahDiterapkan: false);

    return _koleksi(koleksi).where((d) => _cocok(d, filter)).map((d) {
      final salinan = _salin(d);
      if (fields != null) {
        salinan.removeWhere((k, _) => k != '_id' && !fields.contains(k));
      }
      return salinan;
    }).toList();
  }

  @override
  Future<RemoteWrite> updateOne(
    String koleksi,
    Map<String, dynamic> filter,
    Map<String, dynamic> update, {
    bool upsert = false,
  }) async {
    panggilan.add(PanggilanRemote('updateOne', koleksi, filter, update, upsert));
    _pastikanOnline('updateOne');
    final injeksi = _ambilInjeksi('updateOne', koleksi);
    if (injeksi != null && !injeksi.sesudah) {
      throw RemoteGagal('updateOne', sesudahDiterapkan: false);
    }

    final hasil = _terapkanUpdate(koleksi, filter, update, upsert);

    final hook = saatMenungguBalasan;
    saatMenungguBalasan = null;
    if (hook != null) await hook();

    if (injeksi != null) {
      throw RemoteGagal('updateOne', sesudahDiterapkan: true);
    }
    return hasil;
  }

  @override
  Future<RemoteWrite> deleteOne(
    String koleksi,
    Map<String, dynamic> filter,
  ) async {
    panggilan.add(PanggilanRemote('deleteOne', koleksi, filter, null, false));
    _pastikanOnline('deleteOne');
    final injeksi = _ambilInjeksi('deleteOne', koleksi);
    if (injeksi != null && !injeksi.sesudah) {
      throw RemoteGagal('deleteOne', sesudahDiterapkan: false);
    }

    final daftar = _koleksi(koleksi);
    final i = daftar.indexWhere((d) => _cocok(d, filter));
    if (i >= 0) daftar.removeAt(i);

    if (injeksi != null) {
      throw RemoteGagal('deleteOne', sesudahDiterapkan: true);
    }
    return RemoteWrite(ok: true, removed: i >= 0 ? 1 : 0);
  }

  // ── Dalaman ─────────────────────────────────────────────────────

  List<Map<String, dynamic>> _koleksi(String nama) =>
      _data.putIfAbsent(nama, () => []);

  void _pastikanOnline(String op) {
    if (!online) throw RemoteGagal(op, sesudahDiterapkan: false);
  }

  _Injeksi? _ambilInjeksi(String op, String koleksi) {
    for (final i in _injeksi) {
      if (i.sisa > 0 && i.op == op && (i.koleksi == null || i.koleksi == koleksi)) {
        i.sisa--;
        return i;
      }
    }
    return null;
  }

  RemoteWrite _terapkanUpdate(
    String koleksi,
    Map<String, dynamic> filter,
    Map<String, dynamic> update,
    bool upsert,
  ) {
    final tolakan = _tolakan[koleksi];
    if (tolakan != null && tolakan.isNotEmpty) {
      return RemoteWrite(ok: false, errorCode: tolakan.removeAt(0));
    }

    final konflik = _periksaOperator(update);
    if (konflik != null) return RemoteWrite(ok: false, errorCode: konflik);

    final daftar = _koleksi(koleksi);
    final i = daftar.indexWhere((d) => _cocok(d, filter));

    if (i >= 0) {
      final lama = daftar[i];
      final baru = _salin(lama);
      final galat = _terapkanOperator(baru, update, sisipan: false);
      if (galat != null) return RemoteWrite(ok: false, errorCode: galat);
      if (_melanggarUnik(koleksi, baru, kecuali: lama)) {
        return const RemoteWrite(
            ok: false, errorCode: RemoteWrite.kodeDuplikat);
      }
      final berubah = !_samaDalam(lama, baru);
      daftar[i] = baru;
      return RemoteWrite(ok: true, matched: 1, modified: berubah ? 1 : 0);
    }

    if (!upsert) return const RemoteWrite(ok: true);

    final baru = _kesetaraanDariFilter(filter);
    final galat = _terapkanOperator(baru, update, sisipan: true);
    if (galat != null) return RemoteWrite(ok: false, errorCode: galat);
    baru.putIfAbsent('_id', ObjectId.new);

    final balapan = _sisipanBalapan.remove(koleksi);
    if (balapan != null) daftar.addAll(balapan);

    if (_melanggarUnik(koleksi, baru)) {
      return const RemoteWrite(ok: false, errorCode: RemoteWrite.kodeDuplikat);
    }
    daftar.add(baru);
    return const RemoteWrite(ok: true, matched: 1, upserted: 1);
  }

  /// Mengembalikan kode galat bila update tidak sah menurut server.
  int? _periksaOperator(Map<String, dynamic> update) {
    final terpakai = <String>{};
    for (final entri in update.entries) {
      if (!entri.key.startsWith(r'$')) return 9; // FailedToParse
      if (const {r'$set', r'$setOnInsert', r'$inc'}.contains(entri.key)) {
        for (final field in (entri.value as Map<String, dynamic>).keys) {
          if (field.contains('.')) {
            throw UnsupportedError('FakeRemote: path bertitik $field');
          }
          if (!terpakai.add(field)) return 40; // ConflictingUpdateOperators
        }
      } else {
        throw UnsupportedError('FakeRemote: operator ${entri.key}');
      }
    }
    return null;
  }

  int? _terapkanOperator(
    Map<String, dynamic> dok,
    Map<String, dynamic> update, {
    required bool sisipan,
  }) {
    final kumpulanSet = update[r'$set'] as Map<String, dynamic>? ?? const {};
    if (kumpulanSet.containsKey('_id') &&
        !(dok.containsKey('_id') && _sama(dok['_id'], kumpulanSet['_id'])) &&
        !sisipan) {
      return 66; // ImmutableField
    }
    dok.addAll(_salin(kumpulanSet));

    if (sisipan) {
      dok.addAll(_salin(
          update[r'$setOnInsert'] as Map<String, dynamic>? ?? const {}));
    }

    final kumpulanInc = update[r'$inc'] as Map<String, dynamic>? ?? const {};
    for (final e in kumpulanInc.entries) {
      final lama = dok[e.key] ?? 0;
      if (lama is! num || e.value is! num) return 14; // TypeMismatch
      dok[e.key] = lama + (e.value as num);
    }
    return null;
  }

  Map<String, dynamic> _kesetaraanDariFilter(Map<String, dynamic> filter) {
    final hasil = <String, dynamic>{};
    for (final e in filter.entries) {
      if (e.key.startsWith(r'$')) continue;
      final v = e.value;
      if (v is Map) {
        if (v.containsKey(r'$eq')) {
          hasil[e.key] = v[r'$eq'];
        } else if (v.containsKey(r'$in') && (v[r'$in'] as List).length == 1) {
          hasil[e.key] = (v[r'$in'] as List).single;
        }
      } else {
        hasil[e.key] = v;
      }
    }
    return hasil;
  }

  bool _melanggarUnik(
    String koleksi,
    Map<String, dynamic> dok, {
    Map<String, dynamic>? kecuali,
  }) {
    for (final field in _unik[koleksi] ?? const <String>{}) {
      final nilai = dok[field];
      if (nilai is! String) continue;
      final bentrok = _koleksi(koleksi)
          .any((d) => !identical(d, kecuali) && _sama(d[field], nilai));
      if (bentrok) return true;
    }
    return false;
  }

  bool _cocok(Map<String, dynamic> dok, Map<String, dynamic> filter) {
    for (final e in filter.entries) {
      if (e.key == r'$or') {
        final cabang = (e.value as List).cast<Map<String, dynamic>>();
        if (!cabang.any((c) => _cocok(dok, c))) return false;
        continue;
      }
      if (e.key.startsWith(r'$')) {
        throw UnsupportedError('FakeRemote: operator ${e.key}');
      }
      if (!_cocokField(dok, e.key, e.value)) return false;
    }
    return true;
  }

  bool _cocokField(Map<String, dynamic> dok, String field, dynamic kondisi) {
    final ada = dok.containsKey(field);
    final nilai = dok[field];

    if (kondisi is! Map) return _sama(nilai, kondisi);

    for (final e in kondisi.entries) {
      switch (e.key) {
        case r'$eq':
          if (!_sama(nilai, e.value)) return false;
        case r'$ne':
          if (_sama(nilai, e.value)) return false;
        case r'$in':
          if (!(e.value as List).any((v) => _sama(nilai, v))) return false;
        case r'$nin':
          if ((e.value as List).any((v) => _sama(nilai, v))) return false;
        case r'$exists':
          if (ada != e.value) return false;
        default:
          throw UnsupportedError('FakeRemote: operator ${e.key}');
      }
    }
    return true;
  }

  /// Kesetaraan BSON: angka dibandingkan nilainya, selebihnya harus sama tipe.
  static bool _sama(dynamic a, dynamic b) {
    if (a is num && b is num) return a == b;
    if (a == null || b == null) return a == b;
    return a.runtimeType == b.runtimeType && a == b;
  }

  static bool _samaDalam(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (!b.containsKey(e.key) || !_sama(e.value, b[e.key])) return false;
    }
    return true;
  }

  static Map<String, dynamic> _salin(Map<String, dynamic> asal) =>
      asal.map((k, v) => MapEntry(k, _salinNilai(v)));

  static dynamic _salinNilai(dynamic v) {
    if (v is Map<String, dynamic>) return _salin(v);
    if (v is List) return v.map(_salinNilai).toList();
    return v;
  }
}
