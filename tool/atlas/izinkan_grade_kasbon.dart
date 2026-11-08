import 'dart:convert';
import 'dart:io';

import 'atlas_koneksi.dart';
import 'atlas_ops.dart';

/// Menambahkan `-` ke enum `grade_terpilih` di validator `transaksi`.
///
///   dart run tool/atlas/izinkan_grade_kasbon.dart [--confirm]
///
/// Tanpa `--confirm` hanya mencetak perbedaannya. Menulis hanya bila validator di
/// server sama persis dengan `transaksi.sebelum.json` (`baca_skema.dart`), lalu
/// membaca ulang dan menyimpannya ke `transaksi.sesudah.json`. Batalkan dengan
/// `kembalikan_skema.dart`.
Future<void> main(List<String> args) => jalankan(() async {
      final opsi = OpsiCli.parse(args);
      final fileSebelum = File('$folderSkema/transaksi.sebelum.json');
      final fileSesudah = File('$folderSkema/transaksi.sesudah.json');
      if (!fileSebelum.existsSync()) {
        stderr.writeln('${fileSebelum.path} belum ada: jalankan baca_skema.dart.');
        exit(1);
      }
      final sebelum = (jsonDecode(fileSebelum.readAsStringSync())
          as Map<String, dynamic>)['validator'] as Map<String, dynamic>;
      final baru = tambahGradeTanpaKualitas(sebelum);

      await denganAtlas((db) async {
        Future<Map<String, dynamic>> baca() async =>
            skemaDariInfo(await db.getCollectionInfos(), 'transaksi');

        final diServer = await baca();
        final bedaServer = bedaSkema(sebelum, diServer['validator']);
        if (bedaServer.isNotEmpty) {
          stderr.writeln('Validator di server sudah berbeda dari file sebelum:');
          bedaServer.forEach(stderr.writeln);
          exit(1);
        }

        bedaSkema(sebelum, baru).forEach(stdout.writeln);
        if (!opsi.konfirmasi) {
          stdout.writeln(
              'DRY-RUN: tidak ada yang ditulis. Tambahkan --confirm untuk menjalankan.');
          return;
        }

        await gantiValidator(db, 'transaksi', baru);

        final sesudah = await baca();
        final selisih = bedaSkema(baru, sesudah['validator']);
        if (selisih.isNotEmpty) {
          stderr.writeln('Validator terbaca berbeda dari yang dikirim:');
          selisih.forEach(stderr.writeln);
          exit(1);
        }
        fileSesudah.writeAsStringSync(
            '${const JsonEncoder.withIndent('  ').convert(sesudah)}\n');
        stdout.writeln('collMod berhasil, ditulis: ${fileSesudah.path}');
        stdout.writeln('validationLevel: ${sesudah['validationLevel']}, '
            'validationAction: ${sesudah['validationAction']}');
      });
    });
