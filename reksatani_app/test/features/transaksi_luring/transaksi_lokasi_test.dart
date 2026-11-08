import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reksatani_app/features/manajer_dashboard/controllers/manajer_peta_controller.dart';
import 'package:reksatani_app/features/transaksi_luring/controllers/transaksi_controller.dart';
import 'package:reksatani_app/features/transaksi_luring/screens/transaksi_screen.dart';
import 'package:reksatani_app/models/hive/komoditas_hive_model.dart';

import '../../support/fake_remote.dart';
import '../../support/saldo_harness.dart';

const _idAgen = 'agen-1';
const _idPetani = 'petani-1';

void main() {
  late FakeRemote remote;
  late Perangkat hp;

  Future<void> pasang() async {
    remote = FakeRemote();
    tanamAgen(remote, _idAgen, 1000000);
    tanamPetani(remote, _idPetani, _idAgen, 0);
    hp = Perangkat(remote, _idAgen);
    await hp.pasang(uangJalan: 1000000);
    await hp.sinkron();
    // Instance baru: objek Hive tidak boleh masuk ke box milik tes lain.
    await hp.hive.komoditasBox.put(
      'gabah',
      KomoditasHiveModel(
        id: 'gabah',
        namaKomoditas: 'Gabah',
        unitSatuan: 'kg',
        gradeKualitas: const [
          {'grade': 'A', 'harga_maks': 100000000.0},
        ],
        diperbaruiOleh: '',
        waktuPembaruan: DateTime(2026),
      ),
    );
  }

  Future<void> bongkar() async {
    await tungguSync();
    await hp.hancurkan();
  }

  Future<bool> simpan(TransaksiController c) => c.simpanTransaksi(
        petaniTerpilih: null,
        namaPenjual: 'Pak',
        komoditasTerpilih: komoditasGabah,
        gradeTerpilih: 'A',
        beratText: '10',
        hargaText: '5000',
        fotoNotaPath: '',
        fotoBarangPath: '',
        izinkanTanpaFoto: true,
      );

  TransaksiController gpsGagal() =>
      TransaksiController(ambilLokasi: () async => null);

  TransaksiController gpsBerhasil() => TransaksiController(
        ambilLokasi: () async => (lat: -6.9, lng: 107.6),
      );

  group('controller', () {
    setUp(pasang);
    tearDown(bongkar);

    test('GPS berhasil: koordinat tersimpan dan terlapor tercatat', () async {
      expect(await simpan(gpsBerhasil()), isTrue);

      final t = hp.hive.transaksiBox.values.single;
      expect(t.latitude, -6.9);
      expect(t.longitude, 107.6);
    });

    test('GPS gagal: transaksi dan saldo tetap tersimpan, terlapor tidak tercatat', () async {
      expect(await simpan(gpsGagal()), isFalse);

      final t = hp.hive.transaksiBox.values.single;
      expect(t.totalBayar, 50000);
      expect(hp.user.sisaUangJalan, 950000);
      expect(t.latitude, 0.0);
      expect(t.longitude, 0.0);
    });

    test('GPS gagal: cloud menerima angka, karena validator menolak null', () async {
      await simpan(gpsGagal());
      await tungguSync();

      final dok = remote.dokumen('transaksi').single;
      expect(dok['latitude'], isA<double>());
      expect(dok['longitude'], isA<double>());
    });

    test('GPS gagal: titiknya tidak muncul di peta manajer', () async {
      await simpan(gpsGagal());
      await simpan(gpsBerhasil());

      final peta = ManajerPetaController().getTransaksiDenganLokasi;
      expect(peta.single.latitude, -6.9);
    });

    test('pencairan melaporkan hal yang sama', () async {
      final petani = hp.petani(_idPetani);

      expect(
        await gpsGagal().simpanKasbonMurni(
          petaniTerpilih: petani,
          nominalKasbonText: '1000',
        ),
        isFalse,
      );
      expect(
        await gpsBerhasil().simpanKasbonMurni(
          petaniTerpilih: petani,
          nominalKasbonText: '1000',
        ),
        isTrue,
      );
    });

    test('tanpa plugin geolocator: terlapor tidak tercatat, tidak melempar', () async {
      expect(await simpan(TransaksiController()), isFalse);
    });
  });

  // Penyimpanan sungguhan memakai I/O Hive yang bisa menggantung di bawah jam palsu
  // `testWidgets`, jadi efek simpannya diuji di grup controller.
  group('layar', () {
    Future<void> simpanLewatLayar(
      WidgetTester tester, {
      required bool lokasiTercatat,
    }) async {
      await tester.binding.setSurfaceSize(const Size(3000, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.runAsync(pasang);

      await tester.pumpWidget(
        MaterialApp(
          home: TransaksiScreen(
            controller: _ControllerTanpaTulis(lokasiTercatat),
            saranKomoditasAi: 'gabah',
            initialNamaPenjualOcr: 'Pak Budi',
            initialDesaOcr: 'Cibiru',
            initialBeratOcr: '10',
            initialHargaOcr: '5000',
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

      final tombol = find.text('Simpan Transaksi');
      await tester.ensureVisible(tombol);
      await tester.pumpAndSettle();
      await tester.tap(tombol);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simpan tanpa foto'));
      await tester.pumpAndSettle();
    }

    testWidgets('GPS gagal: pemberitahuan tampil di lembar sukses', (tester) async {
      await simpanLewatLayar(tester, lokasiTercatat: false);

      expect(find.text('Transaksi Berhasil Disimpan!'), findsOneWidget);
      expect(find.text(TransaksiController.pesanLokasiGagal), findsOneWidget);

      await tester.runAsync(bongkar);
    });

    testWidgets('GPS berhasil: tidak ada pemberitahuan', (tester) async {
      await simpanLewatLayar(tester, lokasiTercatat: true);

      expect(find.text('Transaksi Berhasil Disimpan!'), findsOneWidget);
      expect(find.text(TransaksiController.pesanLokasiGagal), findsNothing);

      await tester.runAsync(bongkar);
    });
  });
}

class _ControllerTanpaTulis extends TransaksiController {
  _ControllerTanpaTulis(this.lokasiTercatat);

  final bool lokasiTercatat;

  @override
  Future<bool> simpanTransaksi({
    required petaniTerpilih,
    required namaPenjual,
    required komoditasTerpilih,
    required gradeTerpilih,
    required beratText,
    required hargaText,
    required fotoNotaPath,
    required fotoBarangPath,
    required izinkanTanpaFoto,
    CatatanGrading grading = const CatatanGrading(),
  }) async =>
      lokasiTercatat;
}
