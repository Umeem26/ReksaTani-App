import 'dart:io';

import 'atlas_koneksi.dart';
import 'atlas_ops.dart';

/// Mengembalikan data uji ke keadaan tanpa transaksi. Lihat README.md.
///
///   dart run tool/atlas/reset_data_uji.dart [--kasbon=N] [--uang-jalan=N] [--confirm]
///
/// Tanpa `--confirm` hanya mencetak apa yang akan dilakukan.
Future<void> main(List<String> args) => jalankan(() async {
      final opsi = OpsiCli.parse(args, izinkanNilai: true);
      await denganAtlas((db) => resetDataUji(
            AtlasRemote(db),
            opsi,
            cetak: stdout.writeln,
          ));
    });
