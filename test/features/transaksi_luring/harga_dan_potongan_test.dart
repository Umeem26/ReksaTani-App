import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reksatani_app/features/transaksi_luring/controllers/transaksi_controller.dart';
import 'package:reksatani_app/features/transaksi_luring/screens/transaksi_screen.dart';
import 'package:reksatani_app/models/hive/komoditas_hive_model.dart';
import 'package:reksatani_app/models/hive/petani_hive_model.dart';

import '../../support/fake_remote.dart';
import '../../support/saldo_harness.dart';

const _idAgen = 'agen-1';
const _idPetani = 'p1';

KomoditasHiveModel _gabah({double maksA = 7500}) => KomoditasHiveModel(
      id: 'gabah',
      namaKomoditas: 'Gabah',
      unitSatuan: 'kg',
      gradeKualitas: [
        {'grade': 'A', 'harga_maks': maksA},
        {'grade': 'B', 'harga_maks': 6000.0},
      ],
      diperbaruiOleh: '',
      waktuPembaruan: DateTime(2026),
    );

/// Jawaban checklist gabah yang menghasilkan Grade A.
const _jawabanGradeA = ['3% atau kurang', 'Seragam, hampir tanpa butir rusak'];

/// Mencatat apa yang dikirim layar, tanpa I/O.
class _ControllerPencatat extends TransaksiController {
  int dipanggil = 0;
  String? harga;
  PetaniHiveModel? petani;

  @override
  Future<bool> simpanTransaksi({
    required PetaniHiveModel? petaniTerpilih,
    required String namaPenjual,
    required KomoditasHiveModel? komoditasTerpilih,
    required String? gradeTerpilih,
    required String beratText,
    required String hargaText,
    required String fotoNotaPath,
    required String fotoBarangPath,
    required bool izinkanTanpaFoto,
    CatatanGrading grading = const CatatanGrading(),
  }) async {
    dipanggil++;
    harga = hargaText;
    petani = petaniTerpilih;
    return true;
  }
}

void main() {
  late FakeRemote remote;
  late Perangkat hp;

  Future<void> pasang({double kasbon = 150000, double maksA = 7500}) async {
    remote = FakeRemote();
    tanamAgen(remote, _idAgen, 5000000);
    tanamPetani(remote, _idPetani, _idAgen, kasbon);
    hp = Perangkat(remote, _idAgen);
    await hp.pasang(uangJalan: 5000000);
    await hp.sinkron();
    await hp.hive.komoditasBox.put('gabah', _gabah(maksA: maksA));
  }

  Future<void> bongkar() async {
    await tungguSync();
    await hp.hancurkan();
  }

  group('angka tersimpan tidak berubah (controller)', () {
    setUp(pasang);
    tearDown(bongkar);

    test('total_bayar bruto, potongan terpisah, kasbon dan uang jalan sesuai KasbonRules', () async {
      await TransaksiController(ambilLokasi: () async => null).simpanTransaksi(
        petaniTerpilih: hp.petani(_idPetani),
        namaPenjual: 'Petani p1',
        komoditasTerpilih: komoditasGabah,
        gradeTerpilih: 'A',
        beratText: '1250',
        hargaText: '2800',
        fotoNotaPath: '',
        fotoBarangPath: '',
        izinkanTanpaFoto: true,
      );
      await tungguSync();

      final t = hp.hive.transaksiBox.values.single;
      expect(t.totalBayar, 3500000);
      expect(t.nominalPotongKasbon, 150000);
      // Delta kasbon -150.000 dan uang jalan -(3.500.000 - 150.000).
      expect(hp.petani(_idPetani).sisaHutangKasbon, 0);
      expect(hp.user.sisaUangJalan, 5000000 - 3350000);
      final dok = remote.dokumen('transaksi').single;
      expect(dok['total_bayar'], 3500000);
      expect(dok['nominal_potong_kasbon'], 150000);
    });
  });

  group('layar', () {
    Future<_ControllerPencatat> buka(
      WidgetTester tester, {
      String? hargaOcr,
      String? saranAi,
      double kasbon = 150000,
      double maksA = 7500,
      String berat = '1250',
    }) async {
      await tester.binding.setSurfaceSize(const Size(1200, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.runAsync(() => pasang(kasbon: kasbon, maksA: maksA));
      final c = _ControllerPencatat();
      await tester.pumpWidget(MaterialApp(
        home: TransaksiScreen(
          controller: c,
          saranKomoditasAi: saranAi,
          initialNamaPenjualOcr: 'Petani p1',
          initialBeratOcr: berat,
          initialHargaOcr: hargaOcr,
        ),
      ));
      await tester.pumpAndSettle();
      return c;
    }

    Future<void> ketuk(WidgetTester tester, Finder f) async {
      await tester.ensureVisible(f);
      await tester.pumpAndSettle();
      await tester.tap(f);
      await tester.pumpAndSettle();
    }

    Future<void> pilihGabahManual(WidgetTester tester) async {
      await ketuk(tester, find.byType(DropdownButtonFormField<KomoditasHiveModel>));
      await tester.tap(find.text('Gabah').last);
      await tester.pumpAndSettle();
    }

    Future<void> isiChecklistGradeA(WidgetTester tester) async {
      for (final opsi in _jawabanGradeA) {
        await ketuk(tester, find.text(opsi));
      }
    }

    Future<void> simpan(WidgetTester tester) async {
      await ketuk(tester, find.text('Simpan Transaksi'));
      final tanpaFoto = find.text('Simpan tanpa foto');
      if (tanpaFoto.evaluate().isNotEmpty) {
        await tester.tap(tanpaFoto);
        await tester.pumpAndSettle();
      }
    }

    String isiHarga(WidgetTester tester) {
      final field = find.ancestor(of: find.text('Harga / kg (Rp)'), matching: find.byType(Column)).first;
      final teks = tester.widget<EditableText>(
        find.descendant(of: field, matching: find.byType(EditableText)),
      );
      return teks.controller.text;
    }

    testWidgets('lembar sukses: total, potongan kasbon, dan dibayar tunai terpisah', (tester) async {
      final c = await buka(tester, hargaOcr: '2800', saranAi: 'gabah');
      await isiChecklistGradeA(tester);
      await simpan(tester);

      expect(c.dipanggil, 1);
      expect(c.petani?.id, _idPetani);
      expect(find.text('Transaksi Berhasil Disimpan!'), findsOneWidget);
      expect(find.text('Total pembelian'), findsOneWidget);
      expect(find.text('Rp 3.500.000'), findsWidgets);
      expect(find.text('Potongan kasbon'), findsOneWidget);
      expect(find.text('- Rp 150.000'), findsOneWidget);
      expect(find.text('Dibayar tunai'), findsOneWidget);
      expect(find.text('Rp 3.350.000'), findsOneWidget);

      await tester.runAsync(bongkar);
    });

    testWidgets('lembar sukses tanpa kasbon: satu baris Total Bayar', (tester) async {
      await buka(tester, hargaOcr: '2800', saranAi: 'gabah', kasbon: 0);
      await isiChecklistGradeA(tester);
      await simpan(tester);

      expect(find.text('Total Bayar'), findsOneWidget);
      expect(find.text('Potongan kasbon'), findsNothing);

      await tester.runAsync(bongkar);
    });

    testWidgets('harga OCR tidak ditimpa harga maks saat memilih komoditas dan grade', (tester) async {
      final c = await buka(tester, hargaOcr: '1950');
      await pilihGabahManual(tester);
      expect(isiHarga(tester), '1950');
      await isiChecklistGradeA(tester);
      expect(isiHarga(tester), '1950');

      await simpan(tester);
      expect(c.harga, '1950');

      await tester.runAsync(bongkar);
    });

    testWidgets('harga OCR di atas batas: tetap tampil, diperingatkan, simpan ditolak', (tester) async {
      final c = await buka(tester, hargaOcr: '9000');
      await pilihGabahManual(tester);
      await isiChecklistGradeA(tester);

      expect(isiHarga(tester), '9000');
      expect(find.textContaining('Harga melebihi batas maksimal pasaran'), findsOneWidget);

      await simpan(tester);
      expect(c.dipanggil, 0);

      await tester.runAsync(bongkar);
    });

    testWidgets('harga maks 0 berarti tanpa batas: harga OCR tinggi tersimpan', (tester) async {
      final c = await buka(tester, hargaOcr: '99999', maksA: 0, berat: '10');
      await pilihGabahManual(tester);
      await isiChecklistGradeA(tester);

      expect(find.textContaining('Harga melebihi batas maksimal pasaran'), findsNothing);
      await simpan(tester);
      expect(c.harga, '99999');

      await tester.runAsync(bongkar);
    });

    testWidgets('kolom harga kosong tetap diisi harga maks grade', (tester) async {
      await buka(tester);
      await pilihGabahManual(tester);
      await isiChecklistGradeA(tester);

      expect(isiHarga(tester), '7500');

      await tester.runAsync(bongkar);
    });
  });
}
