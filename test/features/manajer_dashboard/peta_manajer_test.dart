import 'package:flutter_test/flutter_test.dart';
import 'package:reksatani_app/features/manajer_dashboard/controllers/manajer_peta_controller.dart';
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
    double? lat = -6.9,
    double? lng = 107.6,
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
        latitude: lat,
        longitude: lng,
        statusSinkronisasi: 'synced',
        createdAt: DateTime(2026, 2, 1),
      );

  setUp(() async {
    hp = Perangkat(FakeRemote(), 'manajer-1');
    await hp.pasang(role: 'manajer');

    for (final t in [
      baris('b1', komoditas: 'Gabah', grade: 'A', berat: 100, total: 500000),
      baris('b2', komoditas: 'Sawit', grade: 'B', berat: 10, total: 25000),
      baris(
        'tanpa-gps',
        komoditas: 'Gabah',
        grade: 'A',
        berat: 5,
        total: 9000,
        lat: 0,
        lng: 0,
      ),
      baris(
        'gps-null',
        komoditas: 'Kopi Robusta',
        grade: 'A',
        berat: 7,
        total: 70000,
        lat: null,
        lng: null,
      ),
      baris(
        'k1',
        komoditas: KasbonRules.labelPencairan,
        grade: '-',
        berat: 0,
        total: 300000,
      ),
    ]) {
      await hp.hive.saveTransaksi(t);
    }
  });

  tearDown(() => hp.hancurkan());

  test('valuasi hanya menjumlahkan pembelian', () {
    expect(ManajerPetaController().totalValuasiAktif, 525000);
  });

  test('filter komoditas tidak memuat pencairan', () {
    final daftar = ManajerPetaController().daftarKomoditasUnik;

    expect(daftar, ['Semua', 'Gabah', 'Sawit']);
    expect(daftar, isNot(contains(KasbonRules.labelPencairan)));
  });

  test('valuasi mengikuti filter komoditas dan grade', () {
    final ctrl = ManajerPetaController()..setFilterKomoditas('Gabah');
    expect(ctrl.totalValuasiAktif, 500000);

    ctrl
      ..setFilterKomoditas('Semua')
      ..setFilterGrade('B');
    expect(ctrl.totalValuasiAktif, 25000);
  });

  test('volume tidak berubah oleh pencairan yang beratnya nol', () {
    expect(ManajerPetaController().totalVolumeAktif, 110);
  });

  test('titik pencairan tetap ada di peta, hanya keluar dari valuasi', () {
    final id = ManajerPetaController()
        .getTransaksiDenganLokasi
        .map((t) => t.idLokal);

    expect(id, unorderedEquals(['b1', 'b2', 'k1']));
  });

  test('koordinat null dan 0,0 lama tidak masuk peta maupun filter', () {
    final ctrl = ManajerPetaController();

    expect(
      ctrl.getTransaksiDenganLokasi.map((t) => t.idLokal),
      isNot(anyOf(contains('gps-null'), contains('tanpa-gps'))),
    );
    expect(ctrl.daftarKomoditasUnik, isNot(contains('Kopi Robusta')));
  });

  test('punyaLokasi: null, 0,0, dan satu sisi nol dianggap tanpa lokasi', () {
    TransaksiHiveModel k(double? lat, double? lng) => baris('x',
        komoditas: 'Gabah', grade: 'A', berat: 1, total: 1, lat: lat, lng: lng);

    expect(k(null, null).punyaLokasi, isFalse);
    expect(k(-6.9, null).punyaLokasi, isFalse);
    expect(k(0, 0).punyaLokasi, isFalse);
    expect(k(0, 107.6).punyaLokasi, isFalse);
    expect(k(-6.9, 107.6).punyaLokasi, isTrue);
  });

  test('Lokasi Aktif tidak menghitung pencairan', () {
    final ctrl = ManajerPetaController();

    // b1, b2, k1 digambar; k1 pencairan (grade '-') tidak dihitung.
    expect(ctrl.getTransaksiDenganLokasi, hasLength(3));
    expect(ctrl.jumlahLokasiAktif, 2);
  });

  test('Lokasi Aktif mengikuti filter grade dan tetap tanpa pencairan', () {
    final ctrl = ManajerPetaController()..setFilterGrade('-');

    expect(ctrl.getTransaksiDenganLokasi.single.idLokal, 'k1');
    expect(ctrl.jumlahLokasiAktif, 0);
  });
}
