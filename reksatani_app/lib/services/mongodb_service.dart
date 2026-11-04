import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:mongo_dart/mongo_dart.dart';

import '../core/env/env.dart';

/// Dilempar saat koleksi diminta sebelum koneksi tersedia.
class MongoTidakTerhubung implements Exception {
  const MongoTidakTerhubung();

  @override
  String toString() => 'MongoTidakTerhubung';
}

class MongoDatabase {
  /// Hanya terisi oleh koneksi yang sudah terbuka.
  static Db? _db;
  static Future<void>? _connecting;

  /// Driver tidak punya timeout sendiri, jadi semua batas waktu ada di sini.
  @visibleForTesting
  static Duration batasSambung = const Duration(seconds: 15);
  @visibleForTesting
  static Duration batasPing = const Duration(seconds: 10);
  @visibleForTesting
  static Duration batasTutup = const Duration(seconds: 5);

  /// Cara membuka koneksi. Tes menggantinya agar tidak menyentuh jaringan.
  @visibleForTesting
  static Future<Db> Function() pembuka = _bukaDariEnv;

  static Future<Db> _bukaDariEnv() async {
    final uri = Env.mongoUri;
    if (uri.isEmpty) {
      throw Exception('MONGO_URI is not set in Env');
    }
    final db = await Db.create(uri);
    await db.open();
    return db;
  }

  /// Single-flight: pemanggil bersamaan menunggu upaya yang sama, sehingga tidak
  /// ada dua `Db` yang hidup berbarengan.
  static Future<void> connect() =>
      _connecting ??= _sambung().whenComplete(() => _connecting = null);

  static Future<void> _sambung() async {
    await _buang();
    final calon = pembuka();
    try {
      _db = await calon.timeout(batasSambung);
      developer.log('Terhubung ke MongoDB', name: 'MongoDatabase');
    } on TimeoutException {
      // Upaya yang sudah ditinggalkan bisa saja berhasil belakangan.
      unawaited(calon.then(_tutup, onError: (_) {}));
      rethrow;
    } catch (e) {
      // Pesan exception koneksi bisa berisi detail server, jadi tipenya saja.
      developer.log('Gagal terhubung: ${e.runtimeType}', name: 'MongoDatabase');
      rethrow;
    }
  }

  static DbCollection getCollection(String collectionName) {
    final db = _db;
    if (db == null || !db.isConnected) {
      throw const MongoTidakTerhubung();
    }
    return db.collection(collectionName);
  }

  static Future<bool> ping() async {
    try {
      if (_db?.isConnected != true) {
        await connect().timeout(batasSambung);
      }
      await _db!
          .collection('users')
          .findOne(where.fields(['_id']))
          .timeout(batasPing);
      return true;
    } catch (_) {
      // Socket setengah mati: sambung baru di upaya berikutnya.
      await _buang();
      return false;
    }
  }

  static Future<void> close() => _buang();

  static Future<void> _buang() async {
    final lama = _db;
    _db = null;
    if (lama != null) await _tutup(lama);
  }

  static Future<void> _tutup(Db db) async {
    try {
      await db.close().timeout(batasTutup);
    } catch (e) {
      developer.log('Gagal menutup koneksi: ${e.runtimeType}', name: 'MongoDatabase');
    }
  }
}
