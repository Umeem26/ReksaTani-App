import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reksatani_app/features/auth/screens/onboarding_screen.dart';

/// Teks onboarding harus sesuai fitur nyata: tanpa klaim validasi harga oleh AI,
/// "realtime", atau "aman".
void main() {
  const larangan = ['Validasi harga AI', 'realtime', 'real-time', 'aman', 'secure'];

  String semuaTeks(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
      .join(' | ');

  testWidgets('ketiga halaman memakai teks jujur', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    final terlihat = <String>[];
    for (var i = 0; i < 3; i++) {
      terlihat.add(semuaTeks(tester));
      await tester.drag(find.byType(PageView), const Offset(-600, 0));
      await tester.pump(const Duration(seconds: 1));
    }
    final gabungan = terlihat.join(' || ');

    expect(gabungan, contains('Transaksi tersimpan di HP saat tidak ada sinyal'));
    expect(gabungan, contains('AI hanya menyarankan jenis komoditas'));
    expect(gabungan, contains('data yang sudah tersinkron'));
    for (final kata in larangan) {
      expect(gabungan.toLowerCase(), isNot(contains(kata.toLowerCase())), reason: kata);
    }

    // Lepas layar supaya Timer latar belakang ikut dibatalkan.
    await tester.pumpWidget(const SizedBox());
  });
}
