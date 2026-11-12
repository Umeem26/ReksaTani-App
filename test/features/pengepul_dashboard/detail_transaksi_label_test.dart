import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reksatani_app/models/hive/transaksi_hive_model.dart';
import 'package:reksatani_app/services/saldo/kasbon_rules.dart';
import 'package:reksatani_app/shared/widgets/transaksi_detail_sheet.dart';

TransaksiHiveModel _trx({
  double potongan = 0,
  double total = 2437500,
  String komoditas = 'Sawit',
}) =>
    TransaksiHiveModel(
      idLokal: 'agen-1_1',
      pengepulId: 'agen-1',
      petaniId: 'p1',
      namaPengepul: 'Asep',
      namaPetani: 'Bu Tarsih',
      namaKomoditas: komoditas,
      gradeTerpilih: 'A',
      berat: 1250,
      hargaBeliSatuan: 1950,
      nominalPotongKasbon: potongan,
      totalBayar: total,
      fotoFisikBarang: '',
      fotoNota: '',
      latitude: null,
      longitude: null,
      statusSinkronisasi: 'pending',
      createdAt: DateTime(2026, 11, 9, 10, 30),
    );

void main() {
  /// Ponsel kecil: 360 dp, huruf diperbesar 1,3x.
  Future<void> buka(WidgetTester tester, TransaksiHiveModel trx) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
        child: child!,
      ),
      home: Scaffold(body: SingleChildScrollView(child: TransaksiDetailSheet(trx: trx))),
    ));
    await tester.pumpAndSettle();
  }

  /// Nilai di baris yang sama dengan [label].
  void nilaiBaris(WidgetTester tester, String label, String nilai) {
    final baris = find.ancestor(of: find.text(label), matching: find.byType(Row)).first;
    expect(find.descendant(of: baris, matching: find.text(nilai)), findsOneWidget,
        reason: '$label harus bernilai $nilai');
  }

  testWidgets('dengan kasbon: total pembelian, potongan kasbon, dibayar tunai', (tester) async {
    final trx = _trx(potongan: 150000);
    await buka(tester, trx);

    nilaiBaris(tester, 'Total pembelian', 'Rp 2.437.500');
    nilaiBaris(tester, 'Potongan kasbon', '- Rp 150.000');
    nilaiBaris(tester, 'Dibayar tunai', 'Rp 2.287.500');
    expect(find.text('Total Pembayaran'), findsNothing);
    // Angka tersimpan tidak disentuh.
    expect(trx.totalBayar, 2437500);
    expect(trx.nominalPotongKasbon, 150000);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tanpa kasbon: satu baris Total Bayar, tanpa potongan', (tester) async {
    await buka(tester, _trx());

    nilaiBaris(tester, 'Total Bayar', 'Rp 2.437.500');
    expect(find.text('Total pembelian'), findsNothing);
    expect(find.text('Potongan kasbon'), findsNothing);
    expect(find.text('Dibayar tunai'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pencairan kasbon: tetap Nominal Kasbon', (tester) async {
    await buka(tester, _trx(komoditas: KasbonRules.labelPencairan, total: 500000));

    nilaiBaris(tester, 'Nominal Kasbon', 'Rp 500.000');
    expect(find.text('Dibayar tunai'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
