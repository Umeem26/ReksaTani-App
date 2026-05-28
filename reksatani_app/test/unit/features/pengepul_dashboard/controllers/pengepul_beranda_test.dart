import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:reksatani_app/features/pengepul_dashboard/controllers/beranda_controller.dart';
import 'package:reksatani_app/models/hive/user_hive_model.dart';
import 'package:reksatani_app/models/hive/transaksi_hive_model.dart';
import 'package:reksatani_app/services/hive_service.dart';

void main() {
  late BerandaController controller;
  late Directory tempDir;
  final hiveService = HiveService();

  setUp(() async {
    dotenv.loadFromString(envString: '''
CLOUDINARY_CLOUD_NAME=test
CLOUDINARY_API_KEY=test
CLOUDINARY_API_SECRET=test
CLOUDINARY_UPLOAD_PRESET=test
MONGODB_URI=mongodb://localhost:27017
''');

    tempDir = await Directory.systemTemp.createTemp('beranda_controller_test');
    Hive.init(tempDir.path);

    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(UserHiveModelAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(TransaksiHiveModelAdapter());

    await Hive.openBox<UserHiveModel>('usersBox');
    await Hive.openBox<TransaksiHiveModel>('transaksiBox');
    await Hive.openBox<dynamic>('settingsBox');
    await Hive.openBox<dynamic>('notifikasiBox');
    await Hive.openBox<dynamic>('petaniBox');
    await Hive.openBox<dynamic>('komoditasBox');

    final mockUser = UserHiveModel(
      id: 'agent_001',
      username: 'Ihsan QA',
      passwordHash: 'hash',
      role: 'pengepul',
      sisaUangJalan: 1000000,
      waktuDibuat: DateTime.now(),
    );
    await hiveService.usersBox.put('currentUser', mockUser);

    controller = BerandaController();
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('BerandaController - Aggregation Unit Tests', () {
    test('TC-BER-001: Positive - Calculate total pengeluaran hari ini', () async {
      final today = DateTime.now();
      
      final t1 = TransaksiHiveModel(
        idLokal: '1', pengepulId: 'agent_001', petaniId: 'p1',
        namaPengepul: 'A', namaPetani: 'P', namaKomoditas: 'K',
        gradeTerpilih: 'A', berat: 10, hargaBeliSatuan: 1000,
        nominalPotongKasbon: 2000, totalBayar: 10000,
        fotoFisikBarang: '', fotoNota: '', statusSinkronisasi: 'pending',
        latitude: 0.0, longitude: 0.0,
        createdAt: today,
      );

      final t2 = TransaksiHiveModel(
        idLokal: '2', pengepulId: 'agent_001', petaniId: 'p2',
        namaPengepul: 'A', namaPetani: 'P', namaKomoditas: 'K',
        gradeTerpilih: 'A', berat: 5, hargaBeliSatuan: 2000,
        nominalPotongKasbon: 0, totalBayar: 10000,
        fotoFisikBarang: '', fotoNota: '', statusSinkronisasi: 'pending',
        latitude: 0.0, longitude: 0.0,
        createdAt: today,
      );

      await hiveService.transaksiBox.putAll({'1': t1, '2': t2});
      expect(controller.totalPengeluaranHariIni, 18000.0);
    });

    test('TC-BER-002: Positive - Calculate total potongan kasbon hari ini', () async {
      final today = DateTime.now();
      
      final t1 = TransaksiHiveModel(
        idLokal: '3', pengepulId: 'agent_001', petaniId: 'p1',
        namaPengepul: 'A', namaPetani: 'P', namaKomoditas: 'K',
        gradeTerpilih: 'A', berat: 10, hargaBeliSatuan: 1000,
        nominalPotongKasbon: 5000, totalBayar: 10000,
        fotoFisikBarang: '', fotoNota: '', statusSinkronisasi: 'pending',
        latitude: 0.0, longitude: 0.0,
        createdAt: today,
      );

      await hiveService.transaksiBox.put('3', t1);
      expect(controller.totalPotonganKasbonHariIni, 5000.0);
    });

    test('TC-BER-003: Edge Case - Should not count transactions from yesterday', () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      
      final tOld = TransaksiHiveModel(
        idLokal: 'old', pengepulId: 'agent_001', petaniId: 'p1',
        namaPengepul: 'A', namaPetani: 'P', namaKomoditas: 'K',
        gradeTerpilih: 'A', berat: 10, hargaBeliSatuan: 1000,
        nominalPotongKasbon: 0, totalBayar: 10000,
        fotoFisikBarang: '', fotoNota: '', statusSinkronisasi: 'pending',
        latitude: 0.0, longitude: 0.0,
        createdAt: yesterday,
      );

      await hiveService.transaksiBox.put('old', tOld);
      expect(controller.totalPengeluaranHariIni, 0.0);
    });
  });
}
