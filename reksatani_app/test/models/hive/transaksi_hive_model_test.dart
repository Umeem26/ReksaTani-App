import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:reksatani_app/models/hive/transaksi_hive_model.dart';
import 'dart:io';

void main() {
  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp();
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(TransaksiHiveModelAdapter());
    }
  });

  tearDownAll(() async {
    await Hive.close();
  });

  group('TransaksiHiveModel Serialization Tests', () {
    test('Should correctly serialize and deserialize TransaksiHiveModel', () async {
      final box = await Hive.openBox<TransaksiHiveModel>('testBox');
      
      final original = TransaksiHiveModel(
        idLokal: 't-001',
        pengepulId: 'a',
        petaniId: 'p',
        namaPengepul: 'Agen',
        namaPetani: 'Petani',
        namaKomoditas: 'Kopi',
        gradeTerpilih: 'B',
        berat: 20.5,
        hargaBeliSatuan: 12000,
        nominalPotongKasbon: 10000,
        totalBayar: 236000,
        fotoFisikBarang: 'foto.jpg',
        fotoNota: 'nota.jpg',
        latitude: 1.0,
        longitude: 2.0,
        statusSinkronisasi: 'pending',
        createdAt: DateTime.now(),
        skorKeyakinan: 0.78,
        isManualGrading: true,
      );

      await box.put('key', original);
      final retrieved = box.get('key');

      expect(retrieved, isNotNull);
      expect(retrieved!.idLokal, original.idLokal);
      expect(retrieved.berat, 20.5);
      expect(retrieved.skorKeyakinan, 0.78);
      expect(retrieved.isManualGrading, isTrue);
      
      await box.close();
    });
  });
}
