import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;
import 'package:reksatani_app/features/transaksi_luring/controllers/transaksi_controller.dart';
import 'package:reksatani_app/features/transaksi_luring/screens/transaksi_screen.dart';
import 'package:reksatani_app/models/hive/komoditas_hive_model.dart';
import 'package:reksatani_app/models/hive/transaksi_hive_model.dart';
import 'package:reksatani_app/services/saldo/transaksi_ditolak.dart';

import '../../support/fake_remote.dart';
import '../../support/saldo_harness.dart';

KomoditasHiveModel _komoditas({double maksA = 7500, double maksB = 6000, double maksC = 0}) =>
    KomoditasHiveModel(
      id: 'gabah',
      namaKomoditas: 'Gabah',
      unitSatuan: 'kg',
      gradeKualitas: [
        {'grade': 'A', 'harga_maks': maksA},
        {'grade': 'B', 'harga_maks': maksB},
        {'grade': 'C', 'harga_maks': maksC},
      ],
      diperbaruiOleh: '',
      waktuPembaruan: DateTime(2026),
    );

Matcher _ditolak(String kode) =>
    throwsA(isA<TransaksiDitolak>().having((e) => e.kode, 'kode', kode));

void main() {
  final oidAgen = ObjectId();
  final oidPetani = ObjectId();
  late FakeRemote remote;
  late Perangkat hp;
  final c = TransaksiController();

  Future<void> pasang() async {
    remote = FakeRemote();
    tanamAgen(remote, oidAgen, 1000000);
    tanamPetani(remote, oidPetani, oidAgen.oid, 100000);
    hp = Perangkat(remote, oidAgen.oid);
    await hp.pasang(uangJalan: 1000000);
    await hp.sinkron();
  }

  Future<void> bongkar() async {
    await tungguSync();
    await hp.hancurkan();
  }

  Future<void> simpan({
    KomoditasHiveModel? komoditas,
    bool tanpaKomoditas = false,
    String? grade = 'A',
    String berat = '10',
    String harga = '5000',
    String nota = '',
    String barang = '',
    bool izin = true,
    bool denganPetani = false,
  }) =>
      c.simpanTransaksi(
        petaniTerpilih: denganPetani ? hp.petani(oidPetani.oid) : null,
        namaPenjual: 'Pak',
        komoditasTerpilih: tanpaKomoditas ? null : (komoditas ?? _komoditas()),
        gradeTerpilih: grade,
        beratText: berat,
        hargaText: harga,
        fotoNotaPath: nota,
        fotoBarangPath: barang,
        izinkanTanpaFoto: izin,
      );

  Future<void> edit(
    TransaksiHiveModel t, {
    KomoditasHiveModel? komoditas,
    String? grade = 'A',
    String berat = '10',
    String harga = '5000',
  }) =>
      c.updateTransaksi(
        t,
        petaniTerpilih: null,
        namaPenjual: 'Pak',
        komoditasTerpilih: komoditas ?? _komoditas(),
        gradeTerpilih: grade,
        beratText: berat,
        hargaText: harga,
        fotoNotaPath: '',
        fotoBarangPath: '',
      );

  void tegaskanTidakAdaYangTertulis() {
    expect(hp.hive.transaksiBox.isEmpty, isTrue);
    expect(hp.user.sisaUangJalan, 1000000);
    expect(hp.petani(oidPetani.oid).sisaHutangKasbon, 100000);
    expect(remote.dokumen('transaksi'), isEmpty);
  }

  group('T20: harga di controller', () {
    setUp(pasang);
    tearDown(bongkar);

    test('melebihi batas: ditolak, tidak menulis Hive, saldo, atau cloud', () async {
      await expectLater(
        simpan(harga: '7501', denganPetani: true),
        _ditolak('harga_melebihi'),
      );
      await tungguSync();
      tegaskanTidakAdaYangTertulis();
    });

    test('tepat di batas: lolos', () async {
      await simpan(harga: '7500');
      await tungguSync();
      expect(hp.hive.transaksiBox.values.single.hargaBeliSatuan, 7500);
    });

    test('nol, negatif, teks, NaN, dan tak hingga ditolak', () async {
      for (final h in ['0', '-1', 'abc', '', 'NaN', 'Infinity']) {
        await expectLater(simpan(harga: h), _ditolak('harga_tidak_sah'), reason: h);
      }
      tegaskanTidakAdaYangTertulis();
    });

    test('tanpa komoditas ditolak: batas harganya tidak diketahui', () async {
      await expectLater(simpan(tanpaKomoditas: true), _ditolak('komoditas_kosong'));
      tegaskanTidakAdaYangTertulis();
    });

    test('grade kosong atau tidak dikenal ditolak: jika tidak, batasnya hilang', () async {
      await expectLater(simpan(grade: null), _ditolak('grade_tidak_dikenal'));
      await expectLater(
        simpan(grade: 'Z', harga: '99999999'),
        _ditolak('grade_tidak_dikenal'),
      );
      tegaskanTidakAdaYangTertulis();
    });

    test('harga_maks 0 tetap berarti tanpa batas', () async {
      await simpan(grade: 'C', harga: '99999');
      await tungguSync();
      expect(hp.hive.transaksiBox.values.single.hargaBeliSatuan, 99999);
    });
  });

  group('Total dihitung di controller', () {
    setUp(pasang);
    tearDown(bongkar);

    test('dari berat dan harga, koma diterima', () async {
      await simpan(berat: '12,5', harga: '5000');
      await tungguSync();

      final t = hp.hive.transaksiBox.values.single;
      expect(t.totalBayar, 62500);
      expect(t.berat, 12.5);
      expect(hp.user.sisaUangJalan, 937500);
      expect(remote.dokumen('transaksi').single['total_bayar'], 62500);
    });

    test('potongan kasbon dihitung dari total itu', () async {
      await simpan(berat: '2', harga: '7000', denganPetani: true);
      await tungguSync();

      final t = hp.hive.transaksiBox.values.single;
      expect(t.totalBayar, 14000);
      expect(t.nominalPotongKasbon, 14000);
      expect(hp.petani(oidPetani.oid).sisaHutangKasbon, 86000);
      expect(hp.user.sisaUangJalan, 1000000);
    });

    test('dibulatkan ke dua desimal: galat double tidak terbawa', () {
      expect(c.getTotalBayar('0,1', '3'), 0.3);
      expect(c.getTotalBayar('1,1', '1,1'), 1.21);
    });

    test('berat nol, negatif, atau tidak sah ditolak', () async {
      for (final b in ['0', '-2', 'abc', '', 'Infinity']) {
        await expectLater(simpan(berat: b), _ditolak('berat_tidak_sah'), reason: b);
      }
      tegaskanTidakAdaYangTertulis();
    });

    test('edit: total dihitung ulang, potongan dan kas mengikuti', () async {
      await simpan(berat: '10', harga: '5000');
      await tungguSync();
      final t = hp.hive.transaksiBox.values.single;

      await edit(t, berat: '20');
      await tungguSync();

      expect(t.totalBayar, 100000);
      expect(hp.user.sisaUangJalan, 900000);
      expect(remote.dokumen('transaksi').single['total_bayar'], 100000);
    });
  });

  group('T20: harga saat edit', () {
    setUp(pasang);
    tearDown(bongkar);

    Future<TransaksiHiveModel> transaksiLama() async {
      await simpan(harga: '7000');
      await tungguSync();
      return hp.hive.transaksiBox.values.single;
    }

    test('harga dinaikkan melebihi batas: ditolak tanpa mengubah apa pun', () async {
      final t = await transaksiLama();
      final kas = hp.user.sisaUangJalan;

      await expectLater(edit(t, harga: '7501'), _ditolak('harga_melebihi'));

      expect(t.hargaBeliSatuan, 7000);
      expect(t.totalBayar, 70000);
      expect(t.statusSinkronisasi, 'synced');
      expect(hp.user.sisaUangJalan, kas);
    });

    test('batas diturunkan sesudahnya: koreksi berat tanpa ubah harga tetap lolos', () async {
      final t = await transaksiLama();

      await edit(t, komoditas: _komoditas(maksA: 6000), berat: '11', harga: '7000');
      await tungguSync();

      expect(t.berat, 11);
      expect(t.totalBayar, 77000);
    });

    test('batas diturunkan sesudahnya: mengubah harga kena batas baru', () async {
      final t = await transaksiLama();

      await expectLater(
        edit(t, komoditas: _komoditas(maksA: 6000), harga: '6500'),
        _ditolak('harga_melebihi'),
      );
    });

    test('pindah ke grade dengan batas lebih rendah kena batas itu', () async {
      final t = await transaksiLama();

      await expectLater(edit(t, grade: 'B', harga: '7000'), _ditolak('harga_melebihi'));
    });

    test('komoditas dikosongkan ditolak, label pembelian tidak hilang', () async {
      final t = await transaksiLama();

      await expectLater(
        c.updateTransaksi(
          t,
          petaniTerpilih: null,
          namaPenjual: 'Pak',
          komoditasTerpilih: null,
          gradeTerpilih: 'A',
          beratText: '10',
          hargaText: '7000',
          fotoNotaPath: '',
          fotoBarangPath: '',
        ),
        _ditolak('komoditas_kosong'),
      );
      expect(t.namaKomoditas, 'Gabah');
    });

    test('berat nol ditolak walau harga tidak berubah', () async {
      final t = await transaksiLama();

      await expectLater(edit(t, berat: '0', harga: '7000'), _ditolak('berat_tidak_sah'));
      expect(t.berat, 10);
    });
  });

  group('Aturan foto', () {
    setUp(pasang);
    tearDown(bongkar);

    test('foto kurang tanpa izin: ditolak tanpa menulis', () async {
      await expectLater(simpan(izin: false), _ditolak('foto_kurang'));
      await expectLater(simpan(izin: false, nota: '/a.jpg'), _ditolak('foto_kurang'));
      await expectLater(simpan(izin: false, barang: '/b.jpg'), _ditolak('foto_kurang'));
      tegaskanTidakAdaYangTertulis();
    });

    test('tanpa foto dengan izin: tercatat dilewati, sampai ke cloud', () async {
      await simpan();
      await tungguSync();

      expect(hp.hive.transaksiBox.values.single.statusFoto, 'dilewati');
      expect(remote.dokumen('transaksi').single['status_foto'], 'dilewati');
    });

    test('satu foto dengan izin: tahap foto tetap memprosesnya, bukan langsung dilewati', () async {
      await simpan(nota: '/tidak-ada/nota.jpg');
      await tungguSync();

      // Filenya tidak ada, jadi hasilnya hilang. Kalau baris ini langsung
      // `dilewati`, foto yang ada tidak akan pernah terunggah.
      expect(hp.hive.transaksiBox.values.single.statusFoto, 'hilang');
    });

    test('foto lengkap tidak butuh izin', () async {
      await simpan(izin: false, nota: 'https://cdn/n.jpg', barang: 'https://cdn/b.jpg');
      await tungguSync();

      expect(hp.hive.transaksiBox.values.single.statusFoto, 'ok');
    });

    test('edit tanpa ganti foto tidak diperiksa, transaksi lama tetap bisa diedit', () async {
      await simpan();
      await tungguSync();
      final t = hp.hive.transaksiBox.values.single;

      await edit(t, berat: '11');
      await tungguSync();

      expect(t.berat, 11);
      expect(t.statusFoto, 'dilewati');
    });
  });

  group('Pencairan', () {
    setUp(pasang);
    tearDown(bongkar);

    test('tidak kena aturan harga dan foto', () async {
      await c.simpanKasbonMurni(
        petaniTerpilih: hp.petani(oidPetani.oid),
        nominalKasbonText: '999999',
      );
      await tungguSync();

      expect(hp.hive.transaksiBox.values.single.statusFoto, 'ok');
      expect(hp.petani(oidPetani.oid).sisaHutangKasbon, 1099999);
    });

    test('nominal nol, negatif, atau tidak sah ditolak: negatif akan menambah kas', () async {
      for (final n in ['0', '-50000', 'abc', '', 'Infinity', 'NaN']) {
        await expectLater(
          c.simpanKasbonMurni(
            petaniTerpilih: hp.petani(oidPetani.oid),
            nominalKasbonText: n,
          ),
          _ditolak('nominal_tidak_sah'),
          reason: n,
        );
      }
      tegaskanTidakAdaYangTertulis();
    });
  });

  group('Layar', () {
    Future<void> bukaForm(WidgetTester tester, {String harga = '5000'}) async {
      await tester.binding.setSurfaceSize(const Size(3000, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.runAsync(() async {
        await pasang();
        await hp.hive.komoditasBox.put('gabah', _komoditas());
      });
      await tester.pumpWidget(
        MaterialApp(
          home: TransaksiScreen(
            saranKomoditasAi: 'gabah',
            initialNamaPenjualOcr: 'Pak Budi',
            initialDesaOcr: 'Cibiru',
            initialBeratOcr: '10',
            initialHargaOcr: harga,
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Grade tidak datang dari AI: checklist diisi manusia (hasilnya Grade A).
      for (final opsi in ['3% atau kurang', 'Seragam, hampir tanpa butir rusak']) {
        await tester.ensureVisible(find.text(opsi));
        await tester.tap(find.text(opsi));
        await tester.pumpAndSettle();
      }
    }

    Future<void> tekanSimpan(WidgetTester tester) async {
      final tombol = find.text('Simpan Transaksi');
      await tester.ensureVisible(tombol);
      await tester.pumpAndSettle();
      await tester.tap(tombol);
      await tester.pumpAndSettle();
    }

    testWidgets('foto kurang: "Ambil foto" kembali ke form tanpa menyimpan', (tester) async {
      await bukaForm(tester);

      await tekanSimpan(tester);
      expect(find.text('Foto nota atau barang belum ada. Simpan tanpa foto?'), findsOneWidget);

      await tester.tap(find.text('Ambil foto'));
      await tester.pumpAndSettle();

      expect(find.text('Foto nota atau barang belum ada. Simpan tanpa foto?'), findsNothing);
      expect(hp.hive.transaksiBox.isEmpty, isTrue);

      await tester.runAsync(bongkar);
    });

    testWidgets('"Simpan tanpa foto" meneruskan izin; layar tidak macet saat ditolak', (tester) async {
      // OCR melewati pemeriksaan isian, jadi nilai ini sampai ke controller.
      await bukaForm(tester, harga: 'abc');

      await tekanSimpan(tester);
      await tester.tap(find.text('Simpan tanpa foto'));
      await tester.pumpAndSettle();

      // Pemeriksaan foto ada di depan, jadi pesan ini berarti izin agen sampai.
      expect(find.text('Harga harus lebih dari nol.'), findsOneWidget);
      expect(hp.hive.transaksiBox.isEmpty, isTrue);
      // Tombol bisa ditekan lagi: dialog muncul kembali.
      await tester.pump(const Duration(seconds: 5));
      await tekanSimpan(tester);
      expect(find.text('Simpan tanpa foto'), findsOneWidget);

      await tester.runAsync(bongkar);
    });
  });
}
