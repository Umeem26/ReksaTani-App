import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:reksatani_app/models/hive/transaksi_hive_model.dart';
import 'package:reksatani_app/services/hive_service.dart';

void main() {
  late Directory tempDir;
  final hiveService = HiveService();
  const int totalData = 1000;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_lifecycle_stress');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(TransaksiHiveModelAdapter());
    }
    await hiveService.init(testPath: tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Hive Lifecycle Stress Testing', () {
    
    test('ST-006: Bulk Update & Delete - 1.000 Transactions', () async {
      print('Memulai ST-006: Simulasi Sinkronisasi Massal (Update 1.000 data)...');
      
      for (int i = 0; i < totalData; i++) {
        final trx = TransaksiHiveModel(
          idLokal: 'bulk_$i',
          pengepulId: 'a', petaniId: 'p', namaPengepul: 'n', namaPetani: 'n',
          namaKomoditas: 'K', gradeTerpilih: 'A', berat: 1, hargaBeliSatuan: 1,
          nominalPotongKasbon: 0, totalBayar: 1, fotoFisikBarang: 'f', fotoNota: 'f',
          latitude: 0, longitude: 0, statusSinkronisasi: 'pending', createdAt: DateTime.now(),
        );
        await hiveService.transaksiBox.put(trx.idLokal, trx);
      }
      expect(hiveService.transaksiBox.length, totalData);

      final updateStopwatch = Stopwatch()..start();
      
      final transactions = hiveService.transaksiBox.values.toList();
      for (var trx in transactions) {
        trx.statusSinkronisasi = 'synced';
        trx.waktuDisinkron = DateTime.now();
        await trx.save();
      }
      
      updateStopwatch.stop();
      final updateDuration = updateStopwatch.elapsedMilliseconds;
      final pendingCount = hiveService.getPendingTransaksi().length;
      expect(pendingCount, 0);
      print('Update Massal Selesai:');
      print('   - Durasi: ${updateDuration}ms');
      print('   - Kecepatan: ${(updateDuration / totalData).toStringAsFixed(4)}ms/item');

      print('Memulai Cleanup Massal (Delete 1.000 data)...');
      final deleteStopwatch = Stopwatch()..start();
      
      await hiveService.transaksiBox.clear();
      
      deleteStopwatch.stop();
      final deleteDuration = deleteStopwatch.elapsedMilliseconds;

      expect(hiveService.transaksiBox.length, 0);
      print('Delete Massal Selesai:');
      print('   - Durasi: ${deleteDuration}ms');

      expect(updateDuration, lessThan(5000), reason: 'Bulk update should be efficient.');
      expect(deleteDuration, lessThan(1000), reason: 'Bulk delete (clear) should be near instant.');
    });
  });
}
