import 'dart:io';

import 'atlas_koneksi.dart';
import 'atlas_ops.dart';

/// Membuat index yang dibutuhkan sinkronisasi. Index yang key-nya sudah ada
/// dilewati, apa pun namanya, jadi aman diulang.
///
///   dart run tool/atlas/buat_index.dart [--confirm]
///
/// Tanpa `--confirm` hanya mencetak apa yang akan dilakukan. Bila ada duplikat
/// `id_lokal`, server menolak dan index tidak terbentuk.
Future<void> main(List<String> args) => jalankan(() async {
      final opsi = OpsiCli.parse(args);
      await denganAtlas((db) async {
        final col = db.collection('transaksi');

        try {
          final rencana = rencanaIndex(await col.getIndexes());

          for (final d in rencana.dilewati) {
            stdout.writeln(
                'dilewati: transaksi.${d.spek.nama} (sudah ada: ${d.namaAda})');
          }
          for (final s in rencana.dibuat) {
            stdout.writeln('akan dibuat: transaksi.${s.nama}');
          }
          if (rencana.konflik.isNotEmpty) {
            for (final k in rencana.konflik) {
              stderr.writeln('konflik: transaksi.${k.spek.nama} harus unik, '
                  'tetapi ${k.namaAda} berkunci sama dan tidak unik.');
            }
            exit(1);
          }

          if (!opsi.konfirmasi) {
            stdout.writeln(
                'DRY-RUN: tidak ada yang ditulis. Tambahkan --confirm untuk menjalankan.');
            return;
          }

          for (final s in rencana.dibuat) {
            await col.createIndex(
              keys: s.kunci,
              unique: s.unik ? true : null,
              name: s.nama,
              partialFilterExpression: s.parsial,
            );
            stdout.writeln('dibuat: transaksi.${s.nama}');
          }
        } on Map catch (balasan) {
          // Driver melempar balasan server mentah bila `ok: 0`.
          stderr.writeln(
              'Ditolak server, kode ${balasan['code']} (${balasan['codeName']}).');
          if (balasan['code'] == 11000) {
            stderr.writeln('Ada duplikat id_lokal: lihat kueri_baca.js.');
          }
          exit(1);
        }

        stdout.writeln('Selesai.');
      });
    });
