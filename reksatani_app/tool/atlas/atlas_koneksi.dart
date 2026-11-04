import 'dart:io';

import 'package:mongo_dart/mongo_dart.dart';
import 'package:reksatani_app/services/sync/sync_remote.dart';

/// [SyncRemote] untuk skrip sekali jalan. Tanpa `MongoDatabase` dan `.env`,
/// karena keduanya bagian dari aplikasi Flutter.
class AtlasRemote implements SyncRemote {
  AtlasRemote(this.db);

  final Db db;

  @override
  Future<bool> ping() async => db.isConnected;

  @override
  Future<List<Map<String, dynamic>>> find(
    String koleksi,
    Map<String, dynamic> filter, {
    List<String>? fields,
  }) =>
      db
          .collection(koleksi)
          .modernFind(
            filter: filter,
            projection: fields == null ? null : {for (final f in fields) f: 1},
          )
          .toList();

  @override
  Future<RemoteWrite> updateOne(
    String koleksi,
    Map<String, dynamic> filter,
    Map<String, dynamic> update, {
    bool upsert = false,
  }) async {
    final h =
        await db.collection(koleksi).updateOne(filter, update, upsert: upsert);
    return RemoteWrite(
      ok: h.isSuccess,
      matched: h.nMatched,
      modified: h.nModified,
      upserted: h.nUpserted,
      errorCode: h.writeError?.code ?? h.code,
    );
  }

  @override
  Future<RemoteWrite> deleteOne(
    String koleksi,
    Map<String, dynamic> filter,
  ) async {
    final h = await db.collection(koleksi).deleteOne(filter);
    return RemoteWrite(
      ok: h.isSuccess,
      removed: h.nRemoved,
      errorCode: h.writeError?.code ?? h.code,
    );
  }
}

/// Membuka koneksi dari variabel lingkungan `MONGO_URI`, menjalankan [kerja], lalu
/// menutupnya. URI tidak pernah dicetak.
Future<void> denganAtlas(Future<void> Function(Db db) kerja) async {
  final uri = Platform.environment['MONGO_URI'] ?? '';
  if (uri.isEmpty) {
    stderr.writeln('MONGO_URI belum diatur.');
    exit(2);
  }

  final db = await Db.create(uri);
  try {
    await db.open();
    stdout.writeln('Database: ${db.databaseName}');
    await kerja(db);
  } finally {
    await db.close();
  }
}

/// Menjalankan [utama] dan menerjemahkan kegagalan ke kode keluar, tanpa
/// mencetak isi exception yang bisa memuat detail server.
Future<void> jalankan(Future<void> Function() utama) async {
  try {
    await utama();
  } on FormatException catch (e) {
    stderr.writeln(e.message);
    exit(64);
  } catch (e) {
    stderr.writeln('Gagal: ${e.runtimeType}');
    exit(1);
  }
}
