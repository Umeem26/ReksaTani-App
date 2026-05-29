import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:reksatani_app/services/hive_service.dart';
import 'package:reksatani_app/models/hive/transaksi_hive_model.dart';
import 'dart:io';

void main() {
  late HiveService hiveService;
  late String tempPath;

  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp();
    tempPath = tempDir.path;
    hiveService = HiveService();
    await hiveService.init(testPath: tempPath);
  });

  tearDownAll(() async {
    await Hive.close();
  });

  group('HiveService CRUD Tests', () {
    setUp(() async {
      await hiveService.clearAllData();
    });

    test('Test save and retrieve transaksi', () async {
      final transaksi = TransaksiHiveModel(
        idLokal: 'local-123',
        pengepulId: 'agen-1',
        petaniId: 'petani-1',
        namaPengepul: 'Agen A',
        namaPetani: 'Petani B',
        namaKomoditas: 'Kopi Arabika',
        gradeTerpilih: 'A',
        berat: 10.0,
        hargaBeliSatuan: 15000,
        nominalPotongKasbon: 50000,
        totalBayar: 100000,
        fotoFisikBarang: 'path/to/foto.jpg',
        fotoNota: 'path/to/nota.jpg',
        latitude: -6.123,
        longitude: 106.123,
        statusSinkronisasi: 'pending',
        createdAt: DateTime.now(),
        skorKeyakinan: 0.95,
        isManualGrading: false,
      );

      await hiveService.saveTransaksi(transaksi);

      final retrieved = hiveService.transaksiBox.get('local-123');
      expect(retrieved, isNotNull);
      expect(retrieved!.namaKomoditas, 'Kopi Arabika');
      expect(retrieved.skorKeyakinan, 0.95);
      expect(retrieved.isManualGrading, isFalse);
    });

    test('Test filtering pending transaksi', () async {
      final t1 = TransaksiHiveModel(
        idLokal: 't1',
        pengepulId: 'a', petaniId: 'p', namaPengepul: 'n', namaPetani: 'n',
        namaKomoditas: 'K', gradeTerpilih: 'A', berat: 1, hargaBeliSatuan: 1,
        nominalPotongKasbon: 0, totalBayar: 1, fotoFisikBarang: 'f', fotoNota: 'f',
        latitude: 0, longitude: 0, statusSinkronisasi: 'pending', createdAt: DateTime.now(),
      );
      final t2 = TransaksiHiveModel(
        idLokal: 't2',
        pengepulId: 'a', petaniId: 'p', namaPengepul: 'n', namaPetani: 'n',
        namaKomoditas: 'K', gradeTerpilih: 'A', berat: 1, hargaBeliSatuan: 1,
        nominalPotongKasbon: 0, totalBayar: 1, fotoFisikBarang: 'f', fotoNota: 'f',
        latitude: 0, longitude: 0, statusSinkronisasi: 'synced', createdAt: DateTime.now(),
      );

      await hiveService.saveTransaksi(t1);
      await hiveService.saveTransaksi(t2);

      final pending = hiveService.getPendingTransaksi();
      expect(pending.length, 1);
      expect(pending.first.idLokal, 't1');
    });

    test('Test data persistence (Close and Reopen simulation)', () async {
      await hiveService.settingsBox.put('testKey', 'testValue');
      
      // Init ulang menggunakan path yang sama
      await hiveService.init(testPath: tempPath);
      
      expect(hiveService.settingsBox.get('testKey'), 'testValue');
    });
  });
}
