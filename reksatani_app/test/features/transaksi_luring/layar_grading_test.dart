import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reksatani_app/features/pcd_scanner/widgets/checklist_rubrik.dart';
import 'package:reksatani_app/features/pcd_scanner/widgets/dialog_proses_foto.dart';
import 'package:reksatani_app/features/transaksi_luring/controllers/transaksi_controller.dart';
import 'package:reksatani_app/features/transaksi_luring/screens/transaksi_screen.dart';
import 'package:reksatani_app/models/hive/komoditas_hive_model.dart';
import 'package:reksatani_app/models/hive/petani_hive_model.dart';

import '../../support/fake_remote.dart';
import '../../support/saldo_harness.dart';

const _idAgen = 'agen-1';

KomoditasHiveModel _komoditas(String id, String nama) => KomoditasHiveModel(
      id: id,
      namaKomoditas: nama,
      unitSatuan: 'kg',
      gradeKualitas: const [
        {'grade': 'A', 'harga_maks': 7500.0},
        {'grade': 'B', 'harga_maks': 6000.0},
        {'grade': 'C', 'harga_maks': 4000.0},
      ],
      diperbaruiOleh: '',
      waktuPembaruan: DateTime(2026),
    );

/// Mencatat apa yang dikirim layar, tanpa I/O.
class _ControllerPencatat extends TransaksiController {
  int dipanggil = 0;
  String? komoditas;
  String? grade;
  CatatanGrading? grading;

  @override
  Future<bool> simpanTransaksi({
    required PetaniHiveModel? petaniTerpilih,
    required String namaPenjual,
    required KomoditasHiveModel? komoditasTerpilih,
    required String? gradeTerpilih,
    required String beratText,
    required String hargaText,
    required String fotoNotaPath,
    required String fotoBarangPath,
    required bool izinkanTanpaFoto,
    CatatanGrading grading = const CatatanGrading(),
  }) async {
    dipanggil++;
    komoditas = komoditasTerpilih?.namaKomoditas;
    grade = gradeTerpilih;
    this.grading = grading;
    return true;
  }
}

void main() {
  late Perangkat hp;

  Future<void> pasang() async {
    final remote = FakeRemote();
    tanamAgen(remote, _idAgen, 1000000);
    hp = Perangkat(remote, _idAgen);
    await hp.pasang(uangJalan: 1000000);
    await hp.sinkron();
    await hp.hive.komoditasBox.put('gabah', _komoditas('gabah', 'Gabah'));
    await hp.hive.komoditasBox.put('kopi', _komoditas('kopi', 'Kopi Robusta'));
    await hp.hive.komoditasBox.put('sawit', _komoditas('sawit', 'Sawit'));
  }

  Future<void> bongkar() async {
    await tungguSync();
    await hp.hancurkan();
  }

  /// Ponsel kecil: 360 dp, huruf diperbesar 1,3x.
  void ponselKecil(WidgetTester tester) {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Widget aplikasi(Widget home) => MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: home,
      );

  Future<_ControllerPencatat> buka(
    WidgetTester tester, {
    String? saran,
    double? keyakinan,
  }) async {
    ponselKecil(tester);
    await tester.runAsync(pasang);
    final c = _ControllerPencatat();
    await tester.pumpWidget(aplikasi(TransaksiScreen(
      controller: c,
      saranKomoditasAi: saran,
      keyakinanSaranAi: keyakinan,
      initialNamaPenjualOcr: 'Pak Budi',
      initialDesaOcr: 'Cibiru',
      initialBeratOcr: '10',
    )));
    await tester.pumpAndSettle();
    return c;
  }

  Future<void> ketuk(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<void> tekanSimpan(WidgetTester tester) async {
    final tombol = find.text('Simpan Transaksi');
    await tester.scrollUntilVisible(tombol, 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(tombol);
    await tester.pumpAndSettle();
  }

  Future<void> pilihKomoditas(WidgetTester tester, String nama) async {
    await ketuk(tester, find.byType(DropdownButtonFormField<KomoditasHiveModel>));
    await tester.tap(find.text(nama).last);
    await tester.pumpAndSettle();
  }

  final gradeApaPun = find.byWidgetPredicate(
    (w) => w is Text && RegExp(r'^Grade [ABC]$').hasMatch(w.data ?? ''),
  );

  testWidgets('loading: dialog proses foto muat di 360 dp, huruf 1,3x', (tester) async {
    ponselKecil(tester);
    await tester.pumpWidget(aplikasi(const Scaffold(body: DialogProsesFoto())));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('SEDANG MEMPROSES FOTO...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saran AI: komoditas dan keyakinan tampil, grade baru muncul sesudah checklist',
      (tester) async {
    await buka(tester, saran: 'kelapa_sawit', keyakinan: 0.87);

    expect(find.text('Saran komoditas (AI)'), findsOneWidget);
    expect(find.text('Kelapa Sawit · keyakinan 87%'), findsOneWidget);
    expect(find.text('Ganti komoditas'), findsOneWidget);
    expect(find.text(labelDrafRubrik), findsOneWidget);
    expect(gradeApaPun, findsNothing);
    expect(find.text('Grade belum ditentukan'), findsOneWidget);
    // Kejujuran label: tidak ada "grade AI" atau klaim akurasi.
    expect(find.textContaining(RegExp('grade ai|akurasi', caseSensitive: false)), findsNothing);

    await ketuk(tester, find.text('Di atas 25% sampai 75%', skipOffstage: false));
    expect(gradeApaPun, findsNothing, reason: 'checklist belum lengkap');

    await ketuk(tester, find.text('Tidak', skipOffstage: false));
    expect(find.text('Grade A'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.runAsync(bongkar);
  });

  testWidgets('tanpa saran AI: pilih manual; checklist belum lengkap menahan simpan', (tester) async {
    final c = await buka(tester);

    expect(find.text('Tidak ada saran komoditas'), findsOneWidget);
    expect(find.text('Pilih komoditas secara manual.'), findsOneWidget);
    expect(find.text('Ganti komoditas'), findsNothing);
    expect(find.text('Pilih komoditas dulu untuk menampilkan checklist.'), findsOneWidget);
    expect(gradeApaPun, findsNothing);

    await pilihKomoditas(tester, 'Gabah');
    await ketuk(tester, find.text('3% atau kurang', skipOffstage: false));
    expect(find.text('Jawab semua pertanyaan (1/2) untuk melihat grade.'), findsOneWidget);

    await tekanSimpan(tester);
    expect(find.text('Lengkapi checklist kualitas untuk menentukan grade', skipOffstage: false), findsOneWidget);
    expect(c.dipanggil, 0);
    expect(tester.takeException(), isNull);

    await tester.runAsync(bongkar);
  });

  testWidgets('saran diganti pengguna: pilihan pengguna dan saran AI sama-sama dikirim',
      (tester) async {
    final c = await buka(tester, saran: 'kopi', keyakinan: 0.81);
    expect(find.text('Perkiraan biji cacat (hitam, pecah, berlubang, kulit tanduk, kotoran)'),
        findsOneWidget);

    await ketuk(tester, find.text('Ganti komoditas', skipOffstage: false));
    expect(find.text('Pilih komoditas dulu untuk menampilkan checklist.'), findsOneWidget);
    // Saran tetap terlihat walau pengguna mengganti.
    expect(find.text('Kopi · keyakinan 81%'), findsOneWidget);

    await pilihKomoditas(tester, 'Gabah');
    await ketuk(tester, find.text('Di atas 3% sampai 10%', skipOffstage: false));
    await ketuk(tester, find.text('Seragam, hampir tanpa butir rusak', skipOffstage: false));
    expect(find.text('Grade B'), findsOneWidget);

    await tekanSimpan(tester);
    await ketuk(tester, find.text('Simpan tanpa foto', skipOffstage: false));

    expect(c.dipanggil, 1);
    expect(c.komoditas, 'Gabah');
    expect(c.grade, 'B');
    expect(c.grading?.saranKomoditasAi, 'kopi');
    expect(c.grading?.rubrikJawaban, ['kotoran_hampa=3-10', 'butir=seragam']);
    expect(TransaksiController.komoditasDiubah(c.grading?.saranKomoditasAi, c.komoditas!), isTrue);
    expect(tester.takeException(), isNull);

    await tester.runAsync(bongkar);
  });
}
