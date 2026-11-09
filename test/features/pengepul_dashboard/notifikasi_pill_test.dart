import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reksatani_app/features/pengepul_dashboard/screens/notifikasi_screen.dart';
import 'package:reksatani_app/services/notification_service.dart';

import '../../support/fake_remote.dart';
import '../../support/saldo_harness.dart';

const _kanalMetode = 'dev.fluttercommunity.plus/connectivity';
const _kanalStatus = 'dev.fluttercommunity.plus/connectivity_status';

void main() {
  late Perangkat hp;

  Future<void> pasang() async {
    final remote = FakeRemote();
    tanamAgen(remote, 'manajer-1', 0);
    hp = Perangkat(remote, 'manajer-1');
    await hp.pasang(role: 'manajer');
    // Yang terbaru tampil paling atas.
    await NotificationService().addNotification(
        judul: 'Sinkronisasi Gagal', pesan: 'Data belum diperbarui dari server.', tipe: 'error');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await NotificationService().addNotification(
        judul: 'Transaksi Baru', pesan: 'Ada 4 transaksi baru masuk dari agen lapangan.', tipe: 'info');
  }

  Future<void> bongkar() async {
    await tungguSync();
    await hp.hancurkan();
  }

  void koneksi(WidgetTester tester, List<String> hasil) {
    tester.binding.defaultBinaryMessenger
      ..setMockMethodCallHandler(const MethodChannel(_kanalMetode), (_) async => hasil)
      ..setMockMethodCallHandler(const MethodChannel(_kanalStatus), (_) async => null);
  }

  /// Ponsel kecil: 360 dp, huruf diperbesar 1,3x.
  Future<void> buka(WidgetTester tester, List<String> hasilKoneksi) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.runAsync(pasang);
    koneksi(tester, hasilKoneksi);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
        child: child!,
      ),
      home: const NotifikasiScreen(),
    ));
    await tester.pump();
    await tester.pumpAndSettle();
  }

  testWidgets('pill tampil: judul notifikasi pertama tidak tertutup (360 dp, 1,3x)', (tester) async {
    await buka(tester, ['none']);

    final pill = find.textContaining('Mode Luring');
    final judul = find.text('Transaksi Baru');
    expect(pill, findsOneWidget);
    expect(judul, findsOneWidget);

    final kotakPill = tester.getRect(find.ancestor(of: pill, matching: find.byType(Container)).first);
    final kotakJudul = tester.getRect(judul);
    expect(kotakPill.bottom, lessThanOrEqualTo(kotakJudul.top),
        reason: 'pill $kotakPill menutupi judul $kotakJudul');
    expect(tester.takeException(), isNull);

    await tester.runAsync(bongkar);
  });

  testWidgets('tanpa pill: daftar mulai di bawah app bar seperti biasa', (tester) async {
    await buka(tester, ['wifi']);

    expect(find.textContaining('Mode Luring'), findsNothing);
    expect(find.textContaining('Gagal sinkron'), findsNothing);
    final appBar = tester.getRect(find.byType(AppBar));
    final judul = tester.getRect(find.text('Transaksi Baru'));
    // Kartu pertama dimulai 16 dp di bawah app bar, judul berada di dalamnya.
    expect(judul.top - appBar.bottom, lessThan(80));
    expect(tester.takeException(), isNull);

    await tester.runAsync(bongkar);
  });
}
