import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:reksatani_app/features/transaksi/controllers/kasbon_controller.dart';
import 'package:reksatani_app/features/transaksi/widgets/kasbon_calculator_widget.dart';
import 'package:reksatani_app/models/hive/petani_hive_model.dart';

void main() {
  testWidgets('KasbonCalculatorWidget should update values when input changes', (WidgetTester tester) async {
    final mockPetani = PetaniHiveModel(
      id: 'petani-1',
      namaPetani: 'Pak Budi',
      desa: 'Sukamaju',
      pengepulId: 'agen-1',
      sisaHutangKasbon: 500000,
      waktuDibuat: DateTime.now(),
    );

    final controller = KasbonController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<KasbonController>.value(
            value: controller,
            child: KasbonCalculatorWidget(daftarPetani: [mockPetani]),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(DropdownButtonFormField<PetaniHiveModel>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pak Budi').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Sisa Kasbon Saat Ini: Rp 500000'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Berat (Kg)'), '10');
    await tester.pump();

    await tester.enterText(find.widgetWithText(TextFormField, 'Harga per Kg'), '20000');
    await tester.pump();

    expect(find.text('Rp 200000'), findsOneWidget);
    
    expect(find.text('Rp 300000'), findsOneWidget);
  });
}
