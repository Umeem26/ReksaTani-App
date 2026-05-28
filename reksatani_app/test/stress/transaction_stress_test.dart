import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:faker/faker.dart';
import 'package:reksatani_app/models/hive/transaksi_hive_model.dart';
import 'package:reksatani_app/services/hive_service.dart';

void main() {
  late Directory tempDir;
  final faker = Faker();
  final hiveService = HiveService();

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('transaction_stress_test');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(TransaksiHiveModelAdapter());
    await Hive.openBox<TransaksiHiveModel>('transaksiBox');
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Hive Database Stress Testing', () {
    const int totalData = 1000;

    test('ST-001: Massive Data Insertion - $totalData Transactions', () async {
      print('Memulai Injeksi $totalData data transaksi...');
      final stopwatch = Stopwatch()..start();

      for (int i = 0; i < totalData; i++) {
        final id = 'local_$i';
        final mockTrx = TransaksiHiveModel(
          idLokal: id,
          pengepulId: 'agent_001',
          petaniId: 'petani_${faker.guid.guid()}',
          namaPengepul: 'Ihsan QA',
          namaPetani: faker.person.name(),
          namaKomoditas: faker.food.cuisine(),
          gradeTerpilih: 'A',
          berat: faker.randomGenerator.decimal(min: 10, scale: 200),
          hargaBeliSatuan: faker.randomGenerator.integer(15000, min: 5000).toDouble(),
          nominalPotongKasbon: 0,
          totalBayar: 0, 
          fotoFisikBarang: 'https://placehold.co/600x400',
          fotoNota: 'https://placehold.co/600x400',
          latitude: -6.200000,
          longitude: 106.816666,
          statusSinkronisasi: 'pending',
          createdAt: DateTime.now(),
        );
        mockTrx.totalBayar = mockTrx.berat * mockTrx.hargaBeliSatuan;
        
        await hiveService.transaksiBox.put(id, mockTrx);
      }

      stopwatch.stop();
      final duration = stopwatch.elapsedMilliseconds;
      print('Injeksi Selesai dalam ${duration}ms');
      
      expect(hiveService.transaksiBox.length, totalData);
      expect(duration, lessThan(5000), reason: 'Insertion should be faster than 5 seconds');
    });

    test('ST-002: Large Data Query & Aggregation Performance', () async {
      for (int i = 0; i < 500; i++) {
        final mockTrx = TransaksiHiveModel(
          idLokal: 'q_$i',
          pengepulId: 'agent_001',
          petaniId: 'p',
          namaPengepul: 'A', namaPetani: 'P', namaKomoditas: 'K',
          gradeTerpilih: 'A', berat: 10.0, hargaBeliSatuan: 1000.0,
          nominalPotongKasbon: 0, totalBayar: 10000.0,
          fotoFisikBarang: '', fotoNota: '', statusSinkronisasi: 'pending',
          latitude: 0.0, longitude: 0.0,
          createdAt: DateTime.now(),
        );
        await hiveService.transaksiBox.put('q_$i', mockTrx);
      }

      final stopwatch = Stopwatch()..start();
      
      final totalBerat = hiveService.transaksiBox.values
          .fold(0.0, (sum, item) => sum + item.berat);

      stopwatch.stop();
      print('Total Berat dari 500 data: $totalBerat kg');
      print('Query & Agregasi Selesai dalam ${stopwatch.elapsedMilliseconds}ms');

      expect(totalBerat, 5000.0);
      expect(stopwatch.elapsedMilliseconds, lessThan(100), reason: 'Aggregation should be instant (< 100ms)');
    });
  });
}
