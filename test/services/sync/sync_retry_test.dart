import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;
import 'package:reksatani_app/models/hive/transaksi_hive_model.dart';
import 'package:reksatani_app/services/master_data_service.dart';
import 'package:reksatani_app/services/sync/sync_report.dart';
import 'package:reksatani_app/shared/widgets/connectivity_wrapper.dart';

import '../../support/fake_remote.dart';
import '../../support/saldo_harness.dart';

void main() {
  final oidAgen = ObjectId();
  late FakeRemote remote;
  late Perangkat hp;
  late List<Duration> jadwal;
  late List<void Function()> aksi;
  final svc = MasterDataService();

  TransaksiHiveModel trx(String idLokal, {String status = 'pending'}) => TransaksiHiveModel(
        idLokal: idLokal,
        pengepulId: oidAgen.oid,
        petaniId: '',
        namaPengepul: 'Agen',
        namaPetani: 'Pak',
        namaKomoditas: 'Gabah',
        gradeTerpilih: 'A',
        berat: 1,
        hargaBeliSatuan: 1000,
        nominalPotongKasbon: 0,
        totalBayar: 1000,
        fotoFisikBarang: '',
        fotoNota: '',
        latitude: 0,
        longitude: 0,
        statusSinkronisasi: status,
        createdAt: DateTime(2026),
      );

  Future<void> pasang() async {
    remote = FakeRemote();
    tanamAgen(remote, oidAgen, 1000000);
    hp = Perangkat(remote, oidAgen.oid);
    await hp.pasang(uangJalan: 1000000);
    jadwal = [];
    aksi = [];
    svc.penjadwalRetry = (tunda, a) {
      jadwal.add(tunda);
      aksi.add(a);
      return null;
    };
    svc.acakRetry = () => 0.5;
    svc.batasSiklus = const Duration(minutes: 5);
    svc.jam = DateTime.now;
  }

  int jumlahNotifikasiGagal() => hp.hive.notifikasiBox.values
      .where((n) => n.judul == 'Sinkronisasi Gagal')
      .length;

  Future<void> bongkar() async {
    await tungguSync();
    await hp.hancurkan();
  }

  group('Pemicu saat sync berjalan', () {
    setUp(pasang);
    tearDown(bongkar);

    test('tidak dibuang: baris yang disimpan di tengah siklus terkirim tanpa pemicu lain', () async {
      await hp.hive.transaksiBox.put('${oidAgen.oid}_1', trx('${oidAgen.oid}_1'));
      remote.saatMenungguBalasan = () async {
        await hp.hive.transaksiBox.put('${oidAgen.oid}_2', trx('${oidAgen.oid}_2'));
        unawaited(svc.syncAll());
      };

      await svc.syncAll();

      expect(svc.isSyncing, isFalse);
      expect(remote.dokumen('transaksi'), hasLength(2));
      expect(hp.hive.getPendingTransaksi(), isEmpty);
      // Saldo cloud langsung benar, tanpa menunggu pemicu berikutnya.
      expect(remote.dokumen('users').single['sisa_uang_jalan'], 998000);
      expect(jadwal, isEmpty);
    });

    test('pemanggil saat sync berjalan menunggu sampai siklus ulangan selesai', () async {
      await hp.hive.transaksiBox.put('${oidAgen.oid}_1', trx('${oidAgen.oid}_1'));
      final kedua = Completer<Future<void>>();
      remote.saatMenungguBalasan = () async {
        await hp.hive.transaksiBox.put('${oidAgen.oid}_2', trx('${oidAgen.oid}_2'));
        kedua.complete(svc.syncAll());
      };

      unawaited(svc.syncAll());
      await (await kedua.future);

      expect(svc.isSyncing, isFalse);
      expect(remote.dokumen('transaksi'), hasLength(2));
    });

    test('banyak pemicu berbarengan hanya menambah satu siklus', () async {
      await Future.wait([svc.syncAll(), svc.syncAll(), svc.syncAll()]);

      final jumlahSiklus = remote.panggilan
          .where((p) => p.op == 'find' && p.koleksi == 'komoditas')
          .length;
      expect(jumlahSiklus, 2);
    });
  });

  group('T19: sync menggantung', () {
    setUp(pasang);
    tearDown(bongkar);

    test('timeout: isSyncing false, tercatat, retry terjadwal', () async {
      svc.batasSiklus = const Duration(milliseconds: 20);
      final gantung = Completer<void>();
      remote.gantungFind = gantung.future;

      await svc.syncAll();

      expect(svc.isSyncing, isFalse);
      expect(svc.laporanTerakhir!.masalah.single.jenis, 'siklus_timeout');
      expect(jadwal, [const Duration(seconds: 30)]);
      gantung.complete();
    });

    test('siklus lama berhenti sesudah dibatalkan, tidak melanjutkan tahap berikutnya', () async {
      svc.batasSiklus = const Duration(milliseconds: 20);
      final gantung = Completer<void>();
      remote.gantungFind = gantung.future;

      await svc.syncAll();
      final sebelum = remote.panggilan.length;
      remote.gantungFind = null;
      gantung.complete();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // `find` rekonsiliasi yang tadi menggantung memang boleh selesai, tetapi
      // komoditas, agen, petani, dan riwayat tidak boleh ditarik lagi.
      final baru = remote.panggilan.skip(sebelum).where((p) => p.koleksi == 'komoditas');
      expect(baru, isEmpty);
    });

    test('ping menggantung juga kena batas', () async {
      svc.batasSiklus = const Duration(milliseconds: 20);
      final gantung = Completer<void>();
      remote.gantungPing = gantung.future;

      await svc.syncAll();

      expect(svc.isSyncing, isFalse);
      expect(svc.laporanTerakhir!.masalah.single.jenis, 'siklus_timeout');
      expect(jadwal, hasLength(1));
      gantung.complete();
    });

    test('siklus berikutnya setelah timeout berjalan normal', () async {
      svc.batasSiklus = const Duration(milliseconds: 20);
      final gantung = Completer<void>();
      remote.gantungFind = gantung.future;
      await hp.hive.transaksiBox.put('${oidAgen.oid}_1', trx('${oidAgen.oid}_1'));
      await svc.syncAll();
      remote.gantungFind = null;
      gantung.complete();
      svc.batasSiklus = const Duration(minutes: 5);

      await svc.syncAll();

      expect(svc.laporanTerakhir!.gagalSinkron, isFalse);
      expect(remote.dokumen('transaksi'), hasLength(1));
    });
  });

  group('Jadwal retry', () {
    setUp(pasang);
    tearDown(bongkar);

    test('sukses tanpa antrean: tidak dijadwalkan', () async {
      await svc.syncAll();

      expect(svc.laporanTerakhir!.gagalSinkron, isFalse);
      expect(jadwal, isEmpty);
    });

    test('gagal terus: tunda membesar, lalu berhenti di percobaan ke-7', () async {
      remote.online = false;

      await svc.syncAll();
      for (var i = 0; i < 10 && aksi.isNotEmpty; i++) {
        final a = aksi.removeLast();
        a();
        await tungguSync();
      }

      expect(jadwal, const [
        Duration(seconds: 30),
        Duration(minutes: 1),
        Duration(minutes: 2),
        Duration(minutes: 4),
        Duration(minutes: 8),
        Duration(minutes: 15),
      ]);
      expect(svc.gagalBeruntun, 7);
    });

    test('sesudah berhenti, pemicu baru menghidupkan retry lagi', () async {
      remote.online = false;
      await svc.syncAll();
      while (aksi.isNotEmpty) {
        aksi.removeLast()();
        await tungguSync();
      }
      jadwal.clear();

      await svc.syncAll();

      expect(jadwal, [const Duration(seconds: 30)]);
    });

    test('pemicu baru sebelum batas tidak mengulang jadwal dari awal', () async {
      remote.online = false;
      await svc.syncAll();
      await svc.syncAll();

      expect(jadwal, const [Duration(seconds: 30), Duration(minutes: 1)]);
    });

    test('berhasil mengembalikan hitungan ke nol', () async {
      remote.online = false;
      await svc.syncAll();
      await svc.syncAll();
      expect(svc.gagalBeruntun, 2);

      remote.online = true;
      jadwal.clear();
      await svc.syncAll();

      expect(svc.gagalBeruntun, 0);
      expect(jadwal, isEmpty);

      remote.online = false;
      await svc.syncAll();
      expect(jadwal, [const Duration(seconds: 30)]);
    });

    test('T17: satu baris gagal permanen: baris lain terkirim, retry terjadwal lalu berhenti', () async {
      await hp.hive.transaksiBox.put('${oidAgen.oid}_1', trx('${oidAgen.oid}_1'));
      await hp.hive.transaksiBox.put('${oidAgen.oid}_2', trx('${oidAgen.oid}_2'));
      remote.tolakBerikutnya('transaksi', 121);

      await svc.syncAll();

      expect(remote.dokumen('transaksi'), hasLength(1));
      expect(svc.jumlahMenunggu, 1);
      expect(svc.laporanTerakhir!.gagalSinkron, isTrue);
      expect(jadwal, hasLength(1));
    });

    test('masih ada antrean tanpa kegagalan: tetap dijadwalkan', () async {
      // Unggahan harness selalu gagal, jadi fotonya tetap menunggu.
      final file = File('${Directory.systemTemp.path}/retry_foto_${oidAgen.oid}.jpg')
        ..writeAsStringSync('x');
      addTearDown(file.deleteSync);
      final idLokal = '${oidAgen.oid}_1';
      await hp.hive.transaksiBox.put(
        idLokal,
        trx(idLokal, status: 'synced')
          ..statusFoto = 'pending'
          ..fotoNota = file.path,
      );
      remote.tanam('transaksi', {'id_lokal': idLokal, 'pengepul_id': oidAgen.oid});

      await svc.syncAll();

      expect(svc.laporanTerakhir!.gagalSinkron, isFalse);
      expect(svc.gagalBeruntun, 0);
      expect(svc.jumlahMenunggu, 1);
      expect(jadwal, [const Duration(seconds: 30)]);
    });
  });

  group('Klasifikasi kegagalan', () {
    SyncReport laporan(List<String> jenis) => SyncReport(
          masalah: [for (final j in jenis) SyncIssue(tahap: 't', jenis: j, pesan: '')],
          terkirim: 0,
          selesai: DateTime(2026),
        );

    test('tidak dianggap gagal', () {
      expect(laporan([]).gagalSinkron, isFalse);
      expect(
        laporan([
          'belum_dimigrasi',
          'kasbon_negatif',
          'saldo_tidak_terbarui',
          'foto_gagal',
          'hapus_petani_ditolak',
        ]).gagalSinkron,
        isFalse,
      );
    });

    test('dianggap gagal, termasuk jenis yang tidak dikenal', () {
      for (final j in [
        'offline',
        'koneksi_gagal',
        'ditolak_server',
        'dokumen_hilang',
        'siklus_gagal',
        'siklus_timeout',
        'jenis_baru',
      ]) {
        expect(laporan(['foto_gagal', j]).kegagalanPertama?.jenis, j);
      }
    });
  });

  group('Status tersimpan dan notifikasi', () {
    setUp(pasang);
    tearDown(bongkar);

    test('berhasil: waktu tersimpan dan ringkasan menampilkannya', () async {
      await svc.syncAll();

      expect(hp.hive.settingsBox.get('syncTerakhirBerhasil'), isNotNull);
      expect(hp.hive.settingsBox.get('syncJenisGagal'), isNull);
      // `selesai` memakai jam engine harness.
      svc.jam = () => hp.jamSync;
      expect(svc.ringkasanSinkron, 'Terakhir sinkron: 09.00');
      svc.jam = () => hp.jamSync.add(const Duration(days: 1));
      expect(svc.ringkasanSinkron, 'Terakhir sinkron: 01/02 09.00');
    });

    test('belum pernah sinkron', () {
      expect(svc.ringkasanSinkron, 'Belum pernah sinkron');
    });

    test('offline: ringkasan tidak menyebut gagal, antrean tetap terlihat', () async {
      await svc.syncAll();
      remote.online = false;
      await hp.hive.transaksiBox.put('${oidAgen.oid}_1', trx('${oidAgen.oid}_1'));
      await svc.syncAll();

      expect(svc.ringkasanSinkron, startsWith('Terakhir sinkron:'));
      expect(svc.ringkasanSinkron, endsWith(' · 1 data menunggu'));
      expect(jumlahNotifikasiGagal(), 0);
    });

    test('gagal sungguhan: ringkasan menyebutnya, notifikasi hanya saat transisi', () async {
      await hp.hive.transaksiBox.put('${oidAgen.oid}_1', trx('${oidAgen.oid}_1'));
      remote.tolakBerikutnya('transaksi', 121);
      await svc.syncAll();

      expect(svc.ringkasanSinkron, 'Gagal sinkron · 1 data menunggu');
      expect(hp.hive.settingsBox.get('syncJenisGagal'), 'ditolak_server');
      expect(hp.hive.settingsBox.get('syncTerakhirGagal'), isNotNull);
      expect(jumlahNotifikasiGagal(), 1);

      remote.tolakBerikutnya('transaksi', 121);
      await svc.syncAll();
      expect(jumlahNotifikasiGagal(), 1);

      await svc.syncAll();
      expect(svc.ringkasanSinkron, startsWith('Terakhir sinkron:'));

      remote.tolakBerikutnya('transaksi', 121);
      hp.hive.transaksiBox.get('${oidAgen.oid}_1')!.statusSinkronisasi = 'pending';
      await hp.hive.transaksiBox.get('${oidAgen.oid}_1')!.save();
      await svc.syncAll();
      expect(jumlahNotifikasiGagal(), 2);
    });

    test('belum_dimigrasi: bukan kegagalan, dicatat berhasil', () async {
      remote.tanam('petani', {'_id': ObjectId(), 'pengepul_id': oidAgen.oid});

      await svc.syncAll();
      await svc.syncAll();

      expect(svc.laporanTerakhir!.sukses, isFalse);
      expect(svc.laporanTerakhir!.gagalSinkron, isFalse);
      expect(svc.gagalBeruntun, 0);
      expect(svc.perluPeringatanSinkron, isFalse);
      expect(svc.ringkasanSinkron, startsWith('Terakhir sinkron:'));
      expect(jadwal, isEmpty);
    });

    test('perluPeringatanSinkron baru true pada kegagalan kedua', () async {
      remote.online = false;
      await svc.syncAll();
      expect(svc.perluPeringatanSinkron, isFalse);
      await svc.syncAll();
      expect(svc.perluPeringatanSinkron, isTrue);
    });
  });

  group('Pill di layar', () {
    const kanalMetode = 'dev.fluttercommunity.plus/connectivity';
    const kanalStatus = 'dev.fluttercommunity.plus/connectivity_status';

    void pasangPlugin(WidgetTester tester, List<String> koneksi) {
      tester.binding.defaultBinaryMessenger
        ..setMockMethodCallHandler(
          const MethodChannel(kanalMetode),
          (_) async => koneksi,
        )
        ..setMockMethodCallHandler(
          const MethodChannel(kanalStatus),
          (_) async => null,
        );
    }

    testWidgets('online dan gagal dua kali: pill muncul; sembuh: hilang', (tester) async {
      await tester.runAsync(pasang);
      pasangPlugin(tester, ['wifi']);
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ConnectivityWrapper(child: SizedBox()))),
      );
      await tester.pump();

      expect(find.textContaining('Gagal sinkron'), findsNothing);

      remote.online = false;
      await tester.runAsync(() async {
        await hp.hive.transaksiBox.put('${oidAgen.oid}_1', trx('${oidAgen.oid}_1'));
        await svc.syncAll();
      });
      await tester.pump();
      expect(find.textContaining('Gagal sinkron'), findsNothing);

      await tester.runAsync(svc.syncAll);
      await tester.pumpAndSettle();
      expect(find.text('Gagal sinkron · 1 data menunggu'), findsOneWidget);

      remote.online = true;
      await tester.runAsync(svc.syncAll);
      await tester.pumpAndSettle();
      expect(find.textContaining('Gagal sinkron'), findsNothing);

      await tester.runAsync(bongkar);
    });

    testWidgets('perangkat offline: pill offline yang tampil, bukan gagal sinkron', (tester) async {
      await tester.runAsync(pasang);
      pasangPlugin(tester, ['none']);
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ConnectivityWrapper(child: SizedBox()))),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      remote.online = false;
      await tester.runAsync(svc.syncAll);
      await tester.runAsync(svc.syncAll);
      await tester.pumpAndSettle();

      expect(svc.perluPeringatanSinkron, isTrue);
      expect(find.textContaining('Mode Luring'), findsOneWidget);
      expect(find.textContaining('Gagal sinkron'), findsNothing);

      await tester.runAsync(bongkar);
    });
  });
}
