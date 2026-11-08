import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Salinan foto yang menunggu terunggah.
///
/// Foto dari pemindai bisa berada di direktori yang sewaktu-waktu dibersihkan
/// OS, padahal unggahannya bisa baru berhasil berhari-hari kemudian. Karena itu
/// foto disalin ke direktori dokumen aplikasi saat transaksi disimpan.
class FotoTertunda {
  FotoTertunda._();

  static const String _folder = 'foto_tertunda';

  /// Sumber direktori dokumen, supaya bisa diuji tanpa plugin.
  @visibleForTesting
  static Future<Directory> Function() direktoriDokumen =
      getApplicationDocumentsDirectory;

  static bool adalahUrl(String nilai) =>
      nilai.startsWith('http://') || nilai.startsWith('https://');

  static bool adalahPathLokal(String nilai) =>
      nilai.isNotEmpty && !adalahUrl(nilai);

  /// Mengembalikan path salinan. Bila penyalinan gagal, path asli tetap dipakai.
  ///
  /// Nama memuat waktu: memilih foto baru saat edit tidak boleh menimpa file yang
  /// mungkin sedang diunggah, karena URL-nya akan tersimpan untuk foto yang salah.
  static Future<String> salin(
    String path, {
    required String idLokal,
    required String jenis,
  }) async {
    if (!adalahPathLokal(path)) return path;
    try {
      final dokumen = await direktoriDokumen();
      final folder = Directory(p.join(dokumen.path, _folder));
      await folder.create(recursive: true);
      final nama =
          '${idLokal}_${jenis}_${DateTime.now().microsecondsSinceEpoch}.jpg';
      final salinan = await File(path).copy(p.join(folder.path, nama));
      return salinan.path;
    } catch (e) {
      developer.log('Foto tidak bisa disalin: ${e.runtimeType}', name: 'FotoTertunda');
      return path;
    }
  }

  /// Menghapus salinan milik aplikasi. File di luar folder ini bukan milik kita,
  /// misalnya foto dari galeri, jadi tidak disentuh.
  static Future<void> hapusSalinan(String path) async {
    if (!adalahPathLokal(path)) return;
    if (p.basename(p.dirname(path)) != _folder) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (e) {
      // Salinan tertinggal tidak memengaruhi data.
      developer.log('Salinan tidak bisa dihapus: ${e.runtimeType}', name: 'FotoTertunda');
    }
  }
}
