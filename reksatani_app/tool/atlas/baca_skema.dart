import 'dart:convert';
import 'dart:io';

import 'atlas_koneksi.dart';
import 'atlas_ops.dart';

/// Membaca validator keempat koleksi ke `tool/atlas/skema/<koleksi>.sebelum.json`.
///
///   dart run tool/atlas/baca_skema.dart
///
/// Baca saja, tidak menulis ke Atlas. File yang sudah ada tidak ditimpa, karena
/// `kembalikan_skema.dart` memulihkan dari sana: pembacaan sesudah `collMod` akan
/// menghilangkan keadaan semula.
Future<void> main() => jalankan(() async {
      await denganAtlas((db) async {
        final folder = Directory(folderSkema)..createSync(recursive: true);
        final infos = await db.getCollectionInfos();

        for (final koleksi in koleksiSkema) {
          final file = File('${folder.path}/$koleksi.sebelum.json');
          final skema = skemaDariInfo(infos, koleksi);
          if (file.existsSync()) {
            stdout.writeln('dilewati: ${file.path} sudah ada');
            continue;
          }
          file.writeAsStringSync(
              '${const JsonEncoder.withIndent('  ').convert(skema)}\n');
          stdout.writeln('ditulis: ${file.path}');
        }
      });
    });
