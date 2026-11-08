import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reksatani_app/features/pengepul_dashboard/controllers/tren_harga_controller.dart';
import 'package:reksatani_app/features/pengepul_dashboard/screens/tren_harga_screen.dart';
import 'package:reksatani_app/models/hive/komoditas_hive_model.dart';

import '../../support/fake_remote.dart';
import '../../support/saldo_harness.dart';

void main() {
  late Perangkat hp;

  setUp(() async {
    hp = Perangkat(FakeRemote(), 'agen-1');
    await hp.pasang();
    await hp.hive.komoditasBox.put(
      'gabah',
      KomoditasHiveModel(
        id: 'gabah',
        namaKomoditas: 'Gabah',
        unitSatuan: 'kg',
        gradeKualitas: const [
          {'grade': 'A', 'harga_maks': 7500.0},
          {'grade': 'B', 'harga_maks': 0.0},
        ],
        diperbaruiOleh: '',
        waktuPembaruan: DateTime(2026),
      ),
    );
  });

  tearDown(() => hp.hancurkan());

  test('harga yang dipakai adalah harga_maks apa adanya', () {
    final ctrl = TrenHargaController();
    addTearDown(ctrl.dispose);

    final item = ctrl.daftarTren.single;
    expect(item.namaKomoditas, 'Gabah');
    expect(item.grade, 'A');
    expect(item.satuan, 'kg');
    expect(item.hargaSaatIni, 7500);
  });

  testWidgets('layar menampilkan harga dan label, tanpa grafik maupun persentase', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TrenHargaScreen()));
    await tester.pump();

    expect(find.text('Rp 7.500 / kg'), findsOneWidget);
    expect(find.text('Riwayat harga belum tersedia'), findsOneWidget);

    expect(find.byType(CustomPaint).evaluate().where(_gambarGrafik), isEmpty);
    expect(find.textContaining('%'), findsNothing);
    expect(find.textContaining('H-'), findsNothing);
    expect(find.byIcon(Icons.trending_up_rounded), findsNothing);
    expect(find.byIcon(Icons.trending_down_rounded), findsNothing);
  });
}

/// Painter grafik lama bernama `_TrendChartPainter`.
bool _gambarGrafik(Element e) =>
    (e.widget as CustomPaint).painter.runtimeType.toString().contains('Chart');
