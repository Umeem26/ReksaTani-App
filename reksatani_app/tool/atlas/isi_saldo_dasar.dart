import 'dart:io';

import 'atlas_koneksi.dart';
import 'atlas_ops.dart';

/// Mengisi `saldo_dasar_* = sisa_*` untuk dokumen yang belum punya field itu.
///
///   dart run tool/atlas/isi_saldo_dasar.dart [--confirm]
///
/// Tanpa `--confirm` hanya mencetak apa yang akan dilakukan.
Future<void> main(List<String> args) => jalankan(() async {
      final opsi = OpsiCli.parse(args);
      await denganAtlas((db) => isiSaldoDasar(
            AtlasRemote(db),
            opsi,
            cetak: stdout.writeln,
          ));
    });
