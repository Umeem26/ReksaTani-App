import 'package:flutter_test/flutter_test.dart';
import 'package:reksatani_app/services/saldo/kasbon_rules.dart';

void main() {
  group('potongan', () {
    double p(double sisa, double total) =>
        KasbonRules.potongan(sisaKasbon: sisa, totalBayar: total);

    test('kasbon lebih besar dari total: dipotong sebesar total', () {
      expect(p(500000, 100000), 100000);
    });

    test('kasbon lebih kecil dari total: seluruh kasbon dipotong', () {
      expect(p(30000, 100000), 30000);
    });

    test('kasbon nol atau negatif: tidak ada potongan', () {
      expect(p(0, 100000), 0);
      expect(p(-5000, 100000), 0);
    });

    test('total nol atau negatif tidak melempar, potongan tetap nol', () {
      expect(p(50000, 0), 0);
      expect(p(50000, -1), 0);
    });
  });

  test('tunaiKeluar adalah total dikurangi potongan', () {
    expect(KasbonRules.tunaiKeluar(totalBayar: 100000, potongan: 30000), 70000);
  });

  group('isPencairan', () {
    test('mengenali label pencairan tanpa peduli huruf besar', () {
      expect(KasbonRules.isPencairan(KasbonRules.labelPencairan), isTrue);
      expect(KasbonRules.isPencairan('PENCAIRAN KASBON BARU'), isTrue);
      expect(KasbonRules.isPencairan('Pencairan Kasbon'), isTrue);
    });

    test('komoditas biasa bukan pencairan', () {
      expect(KasbonRules.isPencairan('Gabah'), isFalse);
      expect(KasbonRules.isPencairan(''), isFalse);
    });
  });

  group('delta', () {
    test('pembelian mengurangi kasbon sebesar potongan dan kas sebesar tunai', () {
      expect(
        KasbonRules.deltaKasbon(
            pencairan: false, totalBayar: 100000, potongan: 30000),
        -30000,
      );
      expect(
        KasbonRules.deltaUangJalan(
            pencairan: false, totalBayar: 100000, potongan: 30000),
        -70000,
      );
    });

    test('pencairan menambah kasbon dan mengurangi kas sebesar total', () {
      expect(
        KasbonRules.deltaKasbon(pencairan: true, totalBayar: 50000, potongan: 0),
        50000,
      );
      expect(
        KasbonRules.deltaUangJalan(
            pencairan: true, totalBayar: 50000, potongan: 0),
        -50000,
      );
    });
  });

  group('hitungEdit', () {
    test('petani sama, total turun: potongan turun, sisanya kembali ke kasbon dan kas', () {
      // Kasbon awal 100.000, total 150.000: potongan 100.000, tunai 50.000.
      final e = KasbonRules.hitungEdit(
        totalLama: 150000,
        potonganLama: 100000,
        totalBaru: 80000,
        uangJalan: 950000,
        petaniSama: true,
        kasbonPetaniLama: 0,
        kasbonPetaniBaru: 0,
      );

      expect(e.potonganBaru, 80000);
      expect(e.kasbonPetaniBaru, 20000);
      expect(e.kasbonPetaniLama, isNull);
      expect(e.uangJalan, 1000000);
    });

    test('petani sama, total naik: potongan dibatasi kasbon yang tersedia', () {
      final e = KasbonRules.hitungEdit(
        totalLama: 150000,
        potonganLama: 100000,
        totalBaru: 300000,
        uangJalan: 950000,
        petaniSama: true,
        kasbonPetaniLama: 0,
        kasbonPetaniBaru: 0,
      );

      expect(e.potonganBaru, 100000);
      expect(e.kasbonPetaniBaru, 0);
      expect(e.uangJalan, 800000);
    });

    test('ganti petani: yang lama dikembalikan, yang baru dipotong dari kasbonnya', () {
      final e = KasbonRules.hitungEdit(
        totalLama: 50000,
        potonganLama: 50000,
        totalBaru: 60000,
        uangJalan: 1000000,
        petaniSama: false,
        kasbonPetaniLama: 50000,
        kasbonPetaniBaru: 40000,
      );

      expect(e.kasbonPetaniLama, 100000);
      expect(e.potonganBaru, 40000);
      expect(e.kasbonPetaniBaru, 0);
      expect(e.uangJalan, 980000);
    });

    test('petani dilepas: yang lama dikembalikan, potongan nol, semua tunai', () {
      final e = KasbonRules.hitungEdit(
        totalLama: 50000,
        potonganLama: 30000,
        totalBaru: 50000,
        uangJalan: 980000,
        petaniSama: false,
        kasbonPetaniLama: 70000,
      );

      expect(e.kasbonPetaniLama, 100000);
      expect(e.potonganBaru, 0);
      expect(e.kasbonPetaniBaru, isNull);
      expect(e.uangJalan, 950000);
    });

    test('tanpa petani sebelum dan sesudah: hanya kas yang berubah', () {
      final e = KasbonRules.hitungEdit(
        totalLama: 50000,
        potonganLama: 0,
        totalBaru: 20000,
        uangJalan: 950000,
        petaniSama: false,
      );

      expect(e.potonganBaru, 0);
      expect(e.kasbonPetaniLama, isNull);
      expect(e.kasbonPetaniBaru, isNull);
      expect(e.uangJalan, 980000);
    });

    test('edit tanpa perubahan nilai tidak mengubah saldo', () {
      final e = KasbonRules.hitungEdit(
        totalLama: 50000,
        potonganLama: 10000,
        totalBaru: 50000,
        uangJalan: 960000,
        petaniSama: true,
        kasbonPetaniLama: 90000,
        kasbonPetaniBaru: 90000,
      );

      expect(e.potonganBaru, 50000);
      expect(e.kasbonPetaniBaru, 50000);
      expect(e.uangJalan, 1000000);
    });
  });
}
