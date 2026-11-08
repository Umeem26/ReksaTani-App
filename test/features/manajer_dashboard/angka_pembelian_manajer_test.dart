import 'package:flutter_test/flutter_test.dart';
import 'package:reksatani_app/features/manajer_dashboard/controllers/manajer_analitik_controller.dart';
import 'package:reksatani_app/features/manajer_dashboard/controllers/manajer_beranda_controller.dart';
import 'package:reksatani_app/models/hive/transaksi_hive_model.dart';
import 'package:reksatani_app/services/saldo/kasbon_rules.dart';

import '../../support/fake_remote.dart';
import '../../support/saldo_harness.dart';

void main() {
  late Perangkat hp;

  TransaksiHiveModel baris(
    String id, {
    required String komoditas,
    required String grade,
    required double berat,
    required double total,
    String status = 'synced',
  }) =>
      TransaksiHiveModel(
        idLokal: id,
        pengepulId: 'agen-1',
        petaniId: 'petani-1',
        namaPengepul: 'agen-1',
        namaPetani: 'Pak Tani',
        namaKomoditas: komoditas,
        gradeTerpilih: grade,
        berat: berat,
        hargaBeliSatuan: berat == 0 ? 0 : total / berat,
        nominalPotongKasbon: 0,
        totalBayar: total,
        fotoFisikBarang: '',
        fotoNota: '',
        latitude: 0,
        longitude: 0,
        statusSinkronisasi: status,
        createdAt: DateTime(2026, 2, 1),
      );

  setUp(() async {
    hp = Perangkat(FakeRemote(), 'manajer-1');
    await hp.pasang(role: 'manajer');

    for (final t in [
      baris('b1', komoditas: 'Gabah', grade: 'A', berat: 100, total: 500000),
      baris('b2', komoditas: 'Gabah', grade: 'B', berat: 50, total: 200000),
      baris('b3', komoditas: 'Sawit', grade: 'A', berat: 10, total: 25000),
      baris(
        'k1',
        komoditas: KasbonRules.labelPencairan,
        grade: '-',
        berat: 0,
        total: 300000,
        status: 'pending',
      ),
    ]) {
      await hp.hive.saveTransaksi(t);
    }
  });

  tearDown(() => hp.hancurkan());

  group('ManajerAnalitikController', () {
    test('totalNilai hanya menjumlahkan pembelian', () {
      expect(ManajerAnalitikController().totalNilai, 725000);
    });

    test('stok per komoditas tidak memuat pencairan', () {
      final data = {
        for (final d in ManajerAnalitikController().stokPerKomoditas)
          d['nama']: d,
      };

      expect(data.keys, isNot(contains(KasbonRules.labelPencairan)));
      expect(data['Gabah']!['totalKg'], 150);
      expect(data['Gabah']!['totalNilai'], 700000);
      expect(data['Sawit']!['totalNilai'], 25000);
    });

    test('rincian grade tidak memuat grade pencairan', () {
      final data = {
        for (final g in ManajerAnalitikController().stokPerGrade)
          g['grade']: g['totalKg'],
      };

      expect(data.keys, isNot(contains('-')));
      expect(data['A'], 110);
      expect(data['B'], 50);
    });

    test('distribusi transaksi hanya menghitung pembelian', () {
      final data = {
        for (final d in ManajerAnalitikController().distribusiTransaksi)
          d['nama']: d['jumlahTransaksi'],
      };

      expect(data.keys, isNot(contains(KasbonRules.labelPencairan)));
      expect(data['Gabah'], 2);
      expect(data['Sawit'], 1);
    });

    test('pembagi distribusi sama dengan jumlah barisnya', () {
      final ctrl = ManajerAnalitikController();
      final jumlah = ctrl.distribusiTransaksi
          .fold<int>(0, (s, d) => s + (d['jumlahTransaksi'] as int));

      expect(ctrl.jumlahPembelian, 3);
      expect(ctrl.jumlahPembelian, jumlah);
    });

    test('status sinkron tetap menghitung pencairan', () {
      final ctrl = ManajerAnalitikController();

      expect(ctrl.semuaTransaksi, hasLength(4));
      expect(ctrl.jumlahPending, 1);
      expect(ctrl.jumlahSynced, 3);
    });
  });

  group('ManajerBerandaController', () {
    test('totalNilai hanya menjumlahkan pembelian', () {
      expect(ManajerBerandaController().totalNilai, 725000);
    });

    test('stok per komoditas tidak memuat pencairan', () {
      final data = ManajerBerandaController().stokPerKomoditas;

      expect(data.keys, unorderedEquals(['Gabah', 'Sawit']));
      expect(data['Gabah'], 150);
    });

    test('status sinkron dan riwayat agen tetap memuat pencairan', () {
      final ctrl = ManajerBerandaController();

      expect(ctrl.jumlahPending, 1);
      expect(ctrl.jumlahSynced, 3);
      expect(
        ctrl.getTransaksiAgen('agen-1').map((t) => t.idLokal),
        contains('k1'),
      );
    });
  });
}
