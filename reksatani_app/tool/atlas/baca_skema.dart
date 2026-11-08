import 'dart:convert';
import 'dart:io';

import 'atlas_koneksi.dart';
import 'atlas_ops.dart';

/// Membaca validator keempat koleksi ke `tool/atlas/skema/<koleksi>.sebelum.json`.
///
///   dart run tool/atlas/baca_skema.dart [--sesudah]
///
/// Baca saja, tidak menulis ke Atlas. File yang sudah ada tidak ditimpa, karena
/// `kembalikan_skema.dart` memulihkan dari sana: pembacaan sesudah `collMod` akan
/// menghilangkan keadaan semula.
///
/// `--sesudah` membaca validator `transaksi` setelah grade `-` ditambahkan di luar
/// skrip ini (misalnya lewat Atlas UI), membandingkannya dengan
/// `transaksi.sebelum.json`, dan menulis `transaksi.sesudah.json` hanya bila
/// satu-satunya perbedaan adalah `-` di enum `grade_terpilih`. Selain itu keluar
/// dengan kode 1 dan mencetak perbedaannya.
Future<void> main(List<String> args) => jalankan(() async {
      final sesudah = switch (args) {
        [] => false,
        ['--sesudah'] => true,
        _ => throw FormatException('Flag tidak dikenal: ${args.join(' ')}'),
      };

      await denganAtlas((db) async {
        final folder = Directory(folderSkema)..createSync(recursive: true);
        final infos = await db.getCollectionInfos();

        if (sesudah) {
          _bacaSesudah(folder, skemaDariInfo(infos, 'transaksi'));
          return;
        }

        for (final koleksi in koleksiSkema) {
          final file = File('${folder.path}/$koleksi.sebelum.json');
          final skema = skemaDariInfo(infos, koleksi);
          if (file.existsSync()) {
            stdout.writeln('dilewati: ${file.path} sudah ada');
            continue;
          }
          _tulisSkema(file, skema);
        }
      });
    });

void _bacaSesudah(Directory folder, Map<String, dynamic> diServer) {
  final fileSebelum = File('${folder.path}/transaksi.sebelum.json');
  if (!fileSebelum.existsSync()) {
    stderr.writeln('${fileSebelum.path} tidak ada.');
    exit(1);
  }
  final sebelum =
      jsonDecode(fileSebelum.readAsStringSync()) as Map<String, dynamic>;

  final beda = bedaSelainGradeTanpaKualitas(sebelum, diServer);
  if (beda.isNotEmpty) {
    stderr.writeln('Validator transaksi berbeda dari ${fileSebelum.path} '
        'selain grade "$gradeTanpaKualitas":');
    beda.forEach(stderr.writeln);
    exit(1);
  }

  bedaSkema(sebelum, diServer).forEach(stdout.writeln);
  _tulisSkema(File('${folder.path}/transaksi.sesudah.json'), diServer);
  stdout.writeln('validationLevel: ${diServer['validationLevel']}, '
      'validationAction: ${diServer['validationAction']}');
}

void _tulisSkema(File file, Map<String, dynamic> skema) {
  file.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(skema)}\n');
  stdout.writeln('ditulis: ${file.path}');
}
