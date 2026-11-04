import 'package:flutter_test/flutter_test.dart';
import 'package:reksatani_app/features/transaksi_luring/controllers/transaksi_controller.dart';
import 'package:reksatani_app/models/hive/petani_hive_model.dart';
import 'package:reksatani_app/models/hive/transaksi_hive_model.dart';
import 'package:reksatani_app/services/saldo/transaksi_ditolak.dart';

import '../../support/fake_remote.dart';
import '../../support/saldo_harness.dart';

const _agen = 'agen-1';
const _petaniA = 'petani-a';
const _petaniB = 'petani-b';

void main() {
  late FakeRemote remote;
  late Perangkat hp;
  late TransaksiController c;

  double kasbonCloud(String id) => remote
      .dokumen('petani')
      .firstWhere((d) => d['_id'] == id)['sisa_hutang_kasbon'] as double;
  double uangJalanCloud() =>
      remote.dokumen('users').single['sisa_uang_jalan'] as double;

  /// Membeli dengan berat 1, sehingga harga sama dengan total.
  Future<TransaksiHiveModel> beli(PetaniHiveModel? petani, double total) async {
    await c.simpanTransaksi(
      petaniTerpilih: petani,
      namaPenjual: petani?.namaPetani ?? 'Tanpa Mitra',
      komoditasTerpilih: komoditasGabah,
      gradeTerpilih: 'A',
      beratText: '1',
      hargaText: total.toStringAsFixed(0),
      totalBayar: total,
      fotoNotaPath: '',
      fotoBarangPath: '',
    );
    await tungguSync();
    return hp.hive.transaksiBox.values.last;
  }

  Future<void> edit(
    TransaksiHiveModel t,
    PetaniHiveModel? petani,
    double total,
  ) async {
    await c.updateTransaksi(
      t,
      petaniTerpilih: petani,
      namaPenjual: petani?.namaPetani ?? 'Tanpa Mitra',
      komoditasTerpilih: komoditasGabah,
      gradeTerpilih: 'A',
      beratText: '1',
      hargaText: total.toStringAsFixed(0),
      totalBayar: total,
      fotoNotaPath: '',
      fotoBarangPath: '',
    );
    await tungguSync();
  }

  setUp(() async {
    remote = FakeRemote();
    tanamAgen(remote, _agen, 1000000);
    tanamPetani(remote, _petaniA, _agen, 100000);
    tanamPetani(remote, _petaniB, _agen, 40000);
    hp = Perangkat(remote, _agen);
    await hp.pasang(uangJalan: 1000000);
    await hp.sinkron();
    c = TransaksiController();
  });

  tearDown(() => hp.hancurkan());

  void cekCloudDanLokal({
    required double kasbonA,
    required double kasbonB,
    required double uangJalan,
  }) {
    expect(kasbonCloud(_petaniA), kasbonA, reason: 'kasbon A cloud');
    expect(kasbonCloud(_petaniB), kasbonB, reason: 'kasbon B cloud');
    expect(uangJalanCloud(), uangJalan, reason: 'uang jalan cloud');
    expect(hp.petani(_petaniA).sisaHutangKasbon, kasbonA, reason: 'kasbon A lokal');
    expect(hp.petani(_petaniB).sisaHutangKasbon, kasbonB, reason: 'kasbon B lokal');
    expect(hp.user.sisaUangJalan, uangJalan, reason: 'uang jalan lokal');
  }

  group('T4: edit mengganti petani', () {
    test('petani lama dan baru benar, di cloud dan lokal', () async {
      final t = await beli(hp.petani(_petaniA), 50000);
      cekCloudDanLokal(kasbonA: 50000, kasbonB: 40000, uangJalan: 1000000);

      await edit(t, hp.petani(_petaniB), 60000);

      cekCloudDanLokal(kasbonA: 100000, kasbonB: 0, uangJalan: 980000);
      final dok = remote.dokumen('transaksi').single;
      expect(dok['petani_id'], _petaniB);
      expect(dok['nominal_potong_kasbon'], 40000);
      expect(t.statusSinkronisasi, 'synced');
    });

    test('saat offline: lokal langsung benar, cloud menyusul setelah sync', () async {
      final t = await beli(hp.petani(_petaniA), 50000);

      remote.online = false;
      await edit(t, hp.petani(_petaniB), 60000);

      expect(hp.petani(_petaniA).sisaHutangKasbon, 100000);
      expect(hp.petani(_petaniB).sisaHutangKasbon, 0);
      expect(hp.user.sisaUangJalan, 980000);
      expect(t.statusSinkronisasi, 'pending_update');
      expect(kasbonCloud(_petaniA), 50000);

      remote.online = true;
      await hp.sinkron();

      cekCloudDanLokal(kasbonA: 100000, kasbonB: 0, uangJalan: 980000);
    });

    test('petani dilepas: dikembalikan, potongan nol, seluruhnya tunai', () async {
      final t = await beli(hp.petani(_petaniA), 50000);

      await edit(t, null, 50000);

      cekCloudDanLokal(kasbonA: 100000, kasbonB: 40000, uangJalan: 950000);
      expect(remote.dokumen('transaksi').single['nominal_potong_kasbon'], 0);
    });

    test('dari tanpa petani ke petani: kasbon petani terpotong', () async {
      final t = await beli(null, 50000);
      cekCloudDanLokal(kasbonA: 100000, kasbonB: 40000, uangJalan: 950000);

      await edit(t, hp.petani(_petaniB), 50000);

      cekCloudDanLokal(kasbonA: 100000, kasbonB: 0, uangJalan: 990000);
    });
  });

  group('T5: edit menurunkan dan menaikkan total', () {
    test('turun: potongan dihitung ulang, selisih kembali, nominal terkirim', () async {
      final t = await beli(hp.petani(_petaniA), 150000);
      cekCloudDanLokal(kasbonA: 0, kasbonB: 40000, uangJalan: 950000);

      await edit(t, hp.petani(_petaniA), 80000);

      cekCloudDanLokal(kasbonA: 20000, kasbonB: 40000, uangJalan: 1000000);
      final dok = remote.dokumen('transaksi').single;
      expect(dok['total_bayar'], 80000);
      expect(dok['nominal_potong_kasbon'], 80000);
    });

    test('naik: potongan dibatasi kasbon, sisanya tunai', () async {
      final t = await beli(hp.petani(_petaniA), 80000);
      cekCloudDanLokal(kasbonA: 20000, kasbonB: 40000, uangJalan: 1000000);

      await edit(t, hp.petani(_petaniA), 300000);

      cekCloudDanLokal(kasbonA: 0, kasbonB: 40000, uangJalan: 800000);
      expect(remote.dokumen('transaksi').single['nominal_potong_kasbon'], 100000);
    });

    test('diedit berkali-kali saat offline: selisih tidak menumpuk', () async {
      final t = await beli(hp.petani(_petaniA), 50000);
      remote.online = false;

      await edit(t, hp.petani(_petaniA), 20000);
      await edit(t, hp.petani(_petaniA), 130000);
      await edit(t, hp.petani(_petaniA), 70000);

      expect(hp.petani(_petaniA).sisaHutangKasbon, 30000);
      expect(hp.user.sisaUangJalan, 1000000);

      remote.online = true;
      await hp.sinkron();

      cekCloudDanLokal(kasbonA: 30000, kasbonB: 40000, uangJalan: 1000000);
    });

    test('baris pending yang belum terkirim tetap pending dan benar', () async {
      remote.online = false;
      final t = await beli(hp.petani(_petaniA), 50000);

      await edit(t, hp.petani(_petaniA), 120000);

      expect(t.statusSinkronisasi, 'pending');
      expect(t.nominalPotongKasbon, 100000);
      expect(hp.petani(_petaniA).sisaHutangKasbon, 0);
      expect(hp.user.sisaUangJalan, 980000);

      remote.online = true;
      await hp.sinkron();

      cekCloudDanLokal(kasbonA: 0, kasbonB: 40000, uangJalan: 980000);
      expect(remote.dokumen('transaksi'), hasLength(1));
    });

    test('sinkron lagi setelah edit tidak mengubah apa pun', () async {
      final t = await beli(hp.petani(_petaniA), 50000);
      await edit(t, hp.petani(_petaniA), 20000);
      final sebelum = remote.panggilan.where((p) => p.update != null).length;

      await hp.sinkron();

      expect(remote.panggilan.where((p) => p.update != null), hasLength(sebelum));
      cekCloudDanLokal(kasbonA: 80000, kasbonB: 40000, uangJalan: 1000000);
    });
  });

  group('pratinjauEdit', () {
    test('kas sesudah edit menghitung tunai lama yang kembali, tanpa menulis apa pun', () async {
      final t = await beli(null, 900000);
      expect(hp.user.sisaUangJalan, 100000);

      final efek = c.pratinjauEdit(t, petaniTerpilih: null, totalBayar: 950000);

      // Kas sekarang 100.000 lebih kecil dari tunai baru, tetapi editnya sah.
      expect(efek.uangJalan, 50000);
      expect(hp.user.sisaUangJalan, 100000);
      expect(t.totalBayar, 900000);
    });
  });

  group('Yang ditolak', () {
    test('pencairan tidak bisa diedit dan tidak ada yang berubah (F12)', () async {
      await c.simpanKasbonMurni(
        petaniTerpilih: hp.petani(_petaniA),
        nominalKasbonText: '30000',
      );
      await tungguSync();
      final t = hp.hive.transaksiBox.values.single;

      await expectLater(
        edit(t, hp.petani(_petaniA), 99),
        throwsA(isA<TransaksiDitolak>()
            .having((e) => e.kode, 'kode', 'pencairan_tidak_bisa_diedit')),
      );

      expect(t.namaKomoditas, 'Pencairan Kasbon Baru');
      expect(t.totalBayar, 30000);
      expect(t.statusSinkronisasi, 'synced');
      cekCloudDanLokal(kasbonA: 130000, kasbonB: 40000, uangJalan: 970000);
    });

    test('baris yang menunggu dihapus tidak bisa diedit', () async {
      final t = await beli(hp.petani(_petaniA), 50000);
      t.statusSinkronisasi = 'pending_delete';
      await t.save();

      await expectLater(
        edit(t, hp.petani(_petaniA), 99),
        throwsA(isA<TransaksiDitolak>()),
      );
      expect(t.totalBayar, 50000);
    });
  });

  test('transaksi milik agen lain di perangkat ini tidak mengubah kas sendiri', () async {
    remote.online = false;
    final t = await beli(null, 50000);
    t.pengepulId = 'agen-lain';
    await t.save();
    final kas = hp.user.sisaUangJalan;

    await edit(t, null, 10000);

    expect(hp.user.sisaUangJalan, kas);
  });
}
