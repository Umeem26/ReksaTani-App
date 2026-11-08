import 'dart:convert';
import 'dart:io';

import 'atlas_koneksi.dart';
import 'atlas_ops.dart';

/// Membatalkan `izinkan_grade_kasbon.dart`: memulihkan validator `transaksi` dari
/// `tool/atlas/skema/transaksi.sebelum.json`.
///
///   dart run tool/atlas/kembalikan_skema.dart [--confirm]
///
/// Tanpa `--confirm` hanya mencetak perbedaannya. Sesudah dipulihkan, pencairan
/// kasbon kembali ditolak dengan kode 121, dan dokumen ber-grade `-` yang sudah ada
/// tidak bisa diperbarui lagi.
Future<void> main(List<String> args) => jalankan(() async {
      final opsi = OpsiCli.parse(args);
      final file = File('$folderSkema/transaksi.sebelum.json');
      if (!file.existsSync()) {
        stderr.writeln('${file.path} tidak ada.');
        exit(1);
      }
      final tujuan = (jsonDecode(file.readAsStringSync())
          as Map<String, dynamic>)['validator'] as Map<String, dynamic>;

      await denganAtlas((db) async {
        Future<Object?> baca() async => skemaDariInfo(
              await db.getCollectionInfos(),
              'transaksi',
            )['validator'];

        final beda = bedaSkema(await baca(), tujuan);
        if (beda.isEmpty) {
          stdout.writeln('Validator sudah sama dengan ${file.path}.');
          return;
        }
        beda.forEach(stdout.writeln);

        final tertahan = await db
            .collection('transaksi')
            .modernFind(
              filter: {'grade_terpilih': gradeTanpaKualitas},
              projection: {'_id': 1},
            )
            .length;
        stdout.writeln('Dokumen ber-grade "$gradeTanpaKualitas": $tertahan');

        if (!opsi.konfirmasi) {
          stdout.writeln(
              'DRY-RUN: tidak ada yang ditulis. Tambahkan --confirm untuk menjalankan.');
          return;
        }

        await gantiValidator(db, 'transaksi', tujuan);

        final selisih = bedaSkema(tujuan, await baca());
        if (selisih.isNotEmpty) {
          stderr.writeln('Validator terbaca berbeda dari yang dikirim:');
          selisih.forEach(stderr.writeln);
          exit(1);
        }
        stdout.writeln('Validator dipulihkan.');
      });
    });
