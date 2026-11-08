import 'package:mongo_dart/mongo_dart.dart' show DbCollection;
// `WriteResult` tidak diekspor oleh pustaka utama mongo_dart. Versinya dikunci
// oleh pubspec.lock, dan bentuknya dijaga oleh mongo_remote_test.dart.
// ignore: implementation_imports
import 'package:mongo_dart/src/database/commands/query_and_write_operation_commands/return_classes/write_result.dart';

import '../mongodb_service.dart';
import 'sync_remote.dart';

/// Implementasi [SyncRemote] di atas `mongo_dart`.
///
/// Driver tidak punya timeout, jadi setiap operasi dibatasi di sini. Timeout pada
/// penulisan berarti hasilnya tidak diketahui. Itu aman karena semua penulisan
/// lewat gerbang ini harus idempoten.
class MongoRemote implements SyncRemote {
  MongoRemote({
    DbCollection Function(String nama)? koleksi,
    this.batasOperasi = const Duration(seconds: 20),
  }) : _koleksi = koleksi ?? MongoDatabase.getCollection;

  final DbCollection Function(String nama) _koleksi;
  final Duration batasOperasi;

  /// Memetakan hasil driver ke [RemoteWrite].
  ///
  /// Dipisah agar bisa diuji dengan balasan simulasi. Driver tidak melempar
  /// exception untuk `ok: 0` maupun write error, jadi keduanya harus terbaca di
  /// sini.
  static RemoteWrite petakan(WriteResult hasil) => RemoteWrite(
        ok: hasil.isSuccess,
        matched: hasil.nMatched,
        modified: hasil.nModified,
        upserted: hasil.nUpserted,
        removed: hasil.nRemoved,
        errorCode: hasil.writeError?.code ?? hasil.code,
      );

  @override
  Future<bool> ping() => MongoDatabase.ping();

  @override
  Future<List<Map<String, dynamic>>> find(
    String koleksi,
    Map<String, dynamic> filter, {
    List<String>? fields,
  }) {
    return _koleksi(koleksi)
        .modernFind(
          filter: filter,
          projection: fields == null ? null : {for (final f in fields) f: 1},
        )
        .toList()
        .timeout(batasOperasi);
  }

  @override
  Future<RemoteWrite> updateOne(
    String koleksi,
    Map<String, dynamic> filter,
    Map<String, dynamic> update, {
    bool upsert = false,
  }) async {
    final hasil = await _koleksi(koleksi)
        .updateOne(filter, update, upsert: upsert)
        .timeout(batasOperasi);
    return petakan(hasil);
  }

  @override
  Future<RemoteWrite> deleteOne(
    String koleksi,
    Map<String, dynamic> filter,
  ) async {
    final hasil =
        await _koleksi(koleksi).deleteOne(filter).timeout(batasOperasi);
    return petakan(hasil);
  }
}
