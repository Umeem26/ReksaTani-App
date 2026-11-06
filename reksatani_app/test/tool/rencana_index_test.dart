import 'package:flutter_test/flutter_test.dart';

import '../../tool/atlas/atlas_ops.dart';

void main() {
  List<String> nama(Iterable<SpekIndex> s) => s.map((x) => x.nama).toList();

  test('collection tanpa index tambahan: semuanya dibuat', () {
    final r = rencanaIndex([
      {
        'name': '_id_',
        'key': {'_id': 1},
      },
    ]);

    expect(nama(r.dibuat), ['uniq_id_lokal', 'idx_petani_id', 'idx_pengepul_id']);
    expect(r.dilewati, isEmpty);
    expect(r.konflik, isEmpty);
  });

  test('key sama dengan nama lain dilewati, index gabungan tidak dihitung', () {
    // Keadaan Atlas saat buat_index pertama kali ditolak dengan kode 85.
    final r = rencanaIndex([
      {
        'name': 'id_lokal_1',
        'key': {'id_lokal': 1},
        'unique': true,
      },
      {
        'name': 'pengepul_id_1_status_sinkronisasi_1',
        'key': {'pengepul_id': 1, 'status_sinkronisasi': 1},
      },
      {
        'name': 'petani_id_1',
        'key': {'petani_id': 1},
      },
    ]);

    expect(nama(r.dibuat), ['idx_pengepul_id']);
    expect(
      r.dilewati.map((d) => '${d.spek.nama}=${d.namaAda}'),
      ['uniq_id_lokal=id_lokal_1', 'idx_petani_id=petani_id_1'],
    );
  });

  test('menjalankan ulang sesudah semua index ada tidak membuat apa pun', () {
    final r = rencanaIndex([
      for (final s in indexTransaksi)
        {'name': s.nama, 'key': s.kunci, if (s.unik) 'unique': true},
    ]);

    expect(r.dibuat, isEmpty);
    expect(r.dilewati, hasLength(3));
  });

  test('index berkunci sama yang tidak unik tidak memenuhi uniq_id_lokal', () {
    final r = rencanaIndex([
      {
        'name': 'id_lokal_biasa',
        'key': {'id_lokal': 1},
      },
    ]);

    expect(r.konflik.map((k) => k.namaAda), ['id_lokal_biasa']);
    expect(nama(r.dibuat), isNot(contains('uniq_id_lokal')));
  });

  test('urutan field dan arah index ikut menentukan', () {
    const spek = [
      SpekIndex(nama: 'x', kunci: {'a': 1, 'b': 1}),
    ];

    expect(
      nama(rencanaIndex([
        {
          'name': 'terbalik',
          'key': {'b': 1, 'a': 1},
        },
      ], spek: spek).dibuat),
      ['x'],
    );
    expect(
      nama(rencanaIndex([
        {
          'name': 'menurun',
          'key': {'a': -1, 'b': 1},
        },
      ], spek: spek).dibuat),
      ['x'],
    );
    expect(
      rencanaIndex([
        {
          'name': 'sama',
          'key': {'a': 1, 'b': 1},
        },
      ], spek: spek).dilewati,
      hasLength(1),
    );
  });
}
