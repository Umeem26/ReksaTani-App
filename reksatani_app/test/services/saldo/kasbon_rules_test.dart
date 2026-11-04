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
}
