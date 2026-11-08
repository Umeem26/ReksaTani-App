import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;
import 'package:reksatani_app/features/manajer_dashboard/controllers/manajemen_komoditas_controller.dart';
import 'package:reksatani_app/features/manajer_dashboard/screens/manajemen_komoditas_screen.dart';

import '../../support/fake_remote.dart';
import '../../support/saldo_harness.dart';

const _kodeValidator = 121;

const _gradeSah = [
  {'grade': 'A', 'harga_maks': 7500.0},
  {'grade': 'B', 'harga_maks': 0.0},
];

void main() {
  late FakeRemote remote;
  late Perangkat hp;
  late ManajemenKomoditasController c;

  setUp(() async {
    remote = FakeRemote();
    hp = Perangkat(remote, 'manajer-1');
    await hp.pasang(role: 'manajer');
    c = ManajemenKomoditasController(remote: remote);
  });

  tearDown(() => hp.hancurkan());

  Future<HasilSimpanKomoditas> tambah({
    List<Map<String, dynamic>> grade = _gradeSah,
  }) =>
      c.tambahKomoditas(
        namaKomoditas: 'Gabah',
        unitSatuan: 'kg',
        gradeKualitas: grade,
      );

  Future<HasilSimpanKomoditas> edit(
    Object id, {
    List<Map<String, dynamic>> grade = _gradeSah,
  }) =>
      c.editKomoditas(
        id: id,
        namaKomoditas: 'Gabah',
        unitSatuan: 'kg',
        gradeKualitas: grade,
      );

  group('validasi form', () {
    test('grade hanya A, B, C, huruf kecil dinormalkan', () {
      for (final sah in ['A', 'B', 'C', 'a', ' c ']) {
        expect(ManajemenKomoditasController.validasiGrade(sah), isNull, reason: sah);
      }
      for (final salah in ['', '  ', 'D', 'AB', '-', 'Premium', null]) {
        expect(ManajemenKomoditasController.validasiGrade(salah), isNotNull, reason: '$salah');
      }
    });

    test('harga harus angka dan tidak negatif, nol boleh', () {
      for (final sah in ['0', '0.0', '7500', ' 7500 ', '12.5']) {
        expect(ManajemenKomoditasController.validasiHarga(sah), isNull, reason: sah);
      }
      for (final salah in ['', ' ', '-1', '-0.5', 'abc', '12,5', 'NaN', 'Infinity', null]) {
        expect(ManajemenKomoditasController.validasiHarga(salah), isNotNull, reason: '$salah');
      }
    });
  });

  group('penjaga sebelum menulis', () {
    final salah = <String, List<Map<String, dynamic>>>{
      'daftar kosong': [],
      'grade di luar A, B, C': [
        {'grade': 'D', 'harga_maks': 100},
      ],
      'grade huruf kecil': [
        {'grade': 'a', 'harga_maks': 100},
      ],
      'harga negatif': [
        {'grade': 'A', 'harga_maks': -1},
      ],
      'harga bukan angka': [
        {'grade': 'A', 'harga_maks': '100'},
      ],
      'harga NaN': [
        {'grade': 'A', 'harga_maks': double.nan},
      ],
      'satu dari dua salah': [
        {'grade': 'A', 'harga_maks': 100},
        {'grade': 'Z', 'harga_maks': 100},
      ],
    };

    salah.forEach((nama, grade) {
      test('tambah ditolak tanpa menulis: $nama', () async {
        expect(await tambah(grade: grade), HasilSimpanKomoditas.tidakValid);
        expect(remote.panggilan, isEmpty);
      });

      test('edit ditolak tanpa menulis: $nama', () async {
        expect(await edit('id-1', grade: grade), HasilSimpanKomoditas.tidakValid);
        expect(remote.panggilan, isEmpty);
      });
    });
  });

  group('tambahKomoditas memeriksa hasil tulis', () {
    test('berhasil: dokumen benar-benar ada', () async {
      expect(await tambah(), HasilSimpanKomoditas.berhasil);

      final dok = remote.dokumen('komoditas').single;
      expect(dok['_id'], isA<String>());
      expect(dok['nama_komoditas'], 'Gabah');
      expect(dok['grade_kualitas'], _gradeSah);
      expect(dok['diperbarui_oleh'], 'manajer-1');
      expect(dok['waktu_pembaruan_harga'], isA<String>());
    });

    test('ditolak validator: gagal, bukan berhasil', () async {
      remote.tolakBerikutnya('komoditas', _kodeValidator);

      expect(await tambah(), HasilSimpanKomoditas.gagal);
      expect(remote.dokumen('komoditas'), isEmpty);
    });

    test('jaringan putus: gagal', () async {
      remote.online = false;

      expect(await tambah(), HasilSimpanKomoditas.gagal);
    });
  });

  group('editKomoditas memeriksa hasil tulis', () {
    test('berhasil pada _id string dan ObjectId', () async {
      final oid = ObjectId();
      remote.tanam('komoditas', {'_id': oid, 'nama_komoditas': 'Lama'});
      remote.tanam('komoditas', {'_id': 'uuid-1', 'nama_komoditas': 'Lama'});

      expect(await edit(oid), HasilSimpanKomoditas.berhasil);
      expect(await edit('uuid-1'), HasilSimpanKomoditas.berhasil);

      expect(
        remote.dokumen('komoditas').map((d) => d['nama_komoditas']),
        ['Gabah', 'Gabah'],
      );
    });

    test('nMatched nol: tidak ditemukan, bukan berhasil', () async {
      expect(await edit('tidak-ada'), HasilSimpanKomoditas.tidakDitemukan);
    });

    test('ditolak validator: gagal dan dokumen tetap', () async {
      remote.tanam('komoditas', {'_id': 'uuid-1', 'nama_komoditas': 'Lama'});
      remote.tolakBerikutnya('komoditas', _kodeValidator);

      expect(await edit('uuid-1'), HasilSimpanKomoditas.gagal);
      expect(remote.dokumen('komoditas').single['nama_komoditas'], 'Lama');
    });

    test('jaringan putus: gagal', () async {
      remote.online = false;

      expect(await edit('uuid-1'), HasilSimpanKomoditas.gagal);
    });
  });

  group('hapus', () {
    test('dokumen terhapus: berhasil', () async {
      remote.tanam('komoditas', {'_id': 'uuid-1', 'nama_komoditas': 'Gabah'});

      expect(await c.hapusKomoditas('uuid-1'), HasilSimpanKomoditas.berhasil);
      expect(remote.dokumen('komoditas'), isEmpty);
    });

    test('tidak ada dokumen yang terhapus: tidak ditemukan, bukan berhasil', () async {
      expect(await c.hapusKomoditas('tidak-ada'), HasilSimpanKomoditas.tidakDitemukan);
    });

    test('jaringan putus: gagal, tidak melempar', () async {
      remote.online = false;

      expect(await c.hapusKomoditas('uuid-1'), HasilSimpanKomoditas.gagal);
    });
  });

  group('layar', () {
    Future<void> bukaForm(WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ManajemenKomoditasScreen(controller: c),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tambah Komoditas'));
      await tester.pumpAndSettle();
    }

    Future<void> isiDanSimpan(
      WidgetTester tester, {
      required String grade,
      required String harga,
    }) async {
      final isian = find.byType(TextFormField);
      await tester.enterText(isian.at(0), 'Gabah');
      await tester.enterText(isian.at(2), grade);
      await tester.enterText(isian.at(3), harga);
      await tester.tap(find.text('Simpan Komoditas'));
      await tester.pumpAndSettle();
    }

    Future<void> hapusLewatMenu(WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ManajemenKomoditasScreen(controller: c),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hapus'));
      await tester.pumpAndSettle();
    }

    void tanamGabah() => remote.tanam('komoditas', {
          '_id': 'uuid-1',
          'nama_komoditas': 'Gabah',
          'unit_satuan': 'kg',
          'grade_kualitas': _gradeSah,
        });

    testWidgets('hapus gagal: pesan tampil, tidak diam-diam', (tester) async {
      tanamGabah();
      await hapusLewatMenu(tester);
      remote.online = false;

      await tester.tap(find.text('Ya, Hapus'));
      await tester.pumpAndSettle();

      expect(
        find.text(ManajemenKomoditasController.pesanGagalHapus(HasilSimpanKomoditas.gagal)),
        findsOneWidget,
      );
    });

    testWidgets('hapus berhasil: tidak ada pesan kegagalan', (tester) async {
      tanamGabah();
      await hapusLewatMenu(tester);

      await tester.tap(find.text('Ya, Hapus'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
      expect(remote.dokumen('komoditas'), isEmpty);
    });

    testWidgets('grade dan harga salah tertahan di form', (tester) async {
      await bukaForm(tester);

      await isiDanSimpan(tester, grade: 'D', harga: '-5');

      expect(find.text('Hanya A, B, C'), findsOneWidget);
      expect(find.text('Harga tidak boleh negatif'), findsOneWidget);
      expect(remote.panggilanTulis('komoditas'), isEmpty);
    });

    testWidgets('penolakan server tampil sebagai kegagalan', (tester) async {
      remote.tolakBerikutnya('komoditas', _kodeValidator);
      await bukaForm(tester);

      await isiDanSimpan(tester, grade: 'A', harga: '7500');

      expect(
        find.text(ManajemenKomoditasController.pesanGagal(HasilSimpanKomoditas.gagal)),
        findsOneWidget,
      );
    });

    testWidgets('penyimpanan berhasil tidak menampilkan kegagalan', (tester) async {
      await bukaForm(tester);

      await isiDanSimpan(tester, grade: 'b', harga: '7500');

      expect(find.byType(SnackBar), findsNothing);
      expect(remote.dokumen('komoditas').single['grade_kualitas'], [
        {'grade': 'B', 'harga_maks': 7500.0},
      ]);
    });
  });
}
