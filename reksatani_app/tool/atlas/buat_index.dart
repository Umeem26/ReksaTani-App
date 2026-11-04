import 'dart:io';

import 'atlas_koneksi.dart';
import 'atlas_ops.dart';

/// Membuat index yang dibutuhkan sinkronisasi. Membuat ulang index yang sama
/// tidak berefek, jadi aman diulang.
///
///   dart run tool/atlas/buat_index.dart [--confirm]
///
/// Tanpa `--confirm` hanya mencetak apa yang akan dilakukan. Bila ada duplikat
/// `id_lokal`, server menolak dan index tidak terbentuk.
Future<void> main(List<String> args) => jalankan(() async {
      final opsi = OpsiCli.parse(args);
      await denganAtlas((db) async {
        final col = db.collection('transaksi');

        stdout.writeln('transaksi.uniq_id_lokal (unik, parsial pada string)');
        stdout.writeln('transaksi.idx_petani_id');
        stdout.writeln('transaksi.idx_pengepul_id');

        if (!opsi.konfirmasi) {
          stdout.writeln(
              'DRY-RUN: tidak ada yang ditulis. Tambahkan --confirm untuk menjalankan.');
          return;
        }

        try {
          await col.createIndex(
            keys: {'id_lokal': 1},
            unique: true,
            name: 'uniq_id_lokal',
            partialFilterExpression: {
              'id_lokal': {r'$type': 'string'},
            },
          );
          await col.createIndex(keys: {'petani_id': 1}, name: 'idx_petani_id');
          await col.createIndex(
              keys: {'pengepul_id': 1}, name: 'idx_pengepul_id');
        } on Map catch (balasan) {
          // Driver melempar balasan server mentah bila `ok: 0`.
          stderr.writeln('Ditolak server, kode ${balasan['code']}. '
              '11000 berarti ada duplikat id_lokal: lihat kueri_baca.js.');
          exit(1);
        }

        stdout.writeln('Selesai.');
      });
    });
