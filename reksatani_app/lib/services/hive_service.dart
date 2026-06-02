import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/hive/user_hive_model.dart';
import '../models/hive/petani_hive_model.dart';
import '../models/hive/komoditas_hive_model.dart';
import '../models/hive/transaksi_hive_model.dart';
import 'notification_service.dart';
import '../models/hive/notifikasi_hive_model.dart';

class HiveService {
  static final HiveService _instance = HiveService._internal();
  factory HiveService() => _instance;
  HiveService._internal();

  static const String _usersBoxName = 'usersBox';
  static const String _petaniBoxName = 'petaniBox';
  static const String _komoditasBoxName = 'komoditasBox';
  static const String _transaksiBoxName = 'transaksiBox';
  static const String _settingsBoxName = 'settingsBox';

  Future<void> init({String? testPath}) async {
    if (testPath != null) {
      Hive.init(testPath);
    } else {
      await Hive.initFlutter();
    }

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(UserHiveModelAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(PetaniHiveModelAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(KomoditasHiveModelAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(TransaksiHiveModelAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(NotifikasiHiveModelAdapter());
    }

    // ── FIX: Membuka Box dengan Sistem Keamanan Auto-Repair ──
    await _openBoxSafe<UserHiveModel>(_usersBoxName);
    await _openBoxSafe<PetaniHiveModel>(_petaniBoxName);
    await _openBoxSafe<KomoditasHiveModel>(_komoditasBoxName);
    await _openBoxSafe<TransaksiHiveModel>(_transaksiBoxName);
    await _openBoxSafe<NotifikasiHiveModel>('notifikasiBox');
    await _openBoxSafe(_settingsBoxName);
  }

  // ── INOVASI: Fungsi Ajaib Anti-Korup ──
  Future<void> _openBoxSafe<T>(String boxName) async {
    try {
      await Hive.openBox<T>(boxName);
    } catch (e) {
      debugPrint('🚨 [HiveService] Box $boxName korup! Melakukan auto-repair...');
      await Hive.deleteBoxFromDisk(boxName); // Hapus data rusak
      await Hive.openBox<T>(boxName);        // Buat ulang yang baru
    }
  }

  Box<UserHiveModel> get usersBox => Hive.box<UserHiveModel>(_usersBoxName);
  Box<PetaniHiveModel> get petaniBox => Hive.box<PetaniHiveModel>(_petaniBoxName);
  Box<KomoditasHiveModel> get komoditasBox => Hive.box<KomoditasHiveModel>(_komoditasBoxName);
  Box<TransaksiHiveModel> get transaksiBox => Hive.box<TransaksiHiveModel>(_transaksiBoxName);
  Box<NotifikasiHiveModel> get notifikasiBox => Hive.box<NotifikasiHiveModel>('notifikasiBox');
  Box get settingsBox => Hive.box(_settingsBoxName);
  
  bool isFirstTime() {
    final hasOnboarded = settingsBox.get('hasOnboarded', defaultValue: false);
    return !hasOnboarded;
  }

  Future<void> completeOnboarding() async {
    await settingsBox.put('hasOnboarded', true);
  }

  Future<void> saveTransaksi(TransaksiHiveModel transaksi) async {
    await transaksiBox.put(transaksi.idLokal, transaksi);
    
    NotificationService().addNotification(
      judul: 'Transaksi Tersimpan',
      pesan: 'Data ${transaksi.namaKomoditas} (${transaksi.berat.toInt()} kg) tersimpan di perangkat. Jangan lupa sinkronisasi saat online.',
      tipe: 'sync',
    );
  }

  List<TransaksiHiveModel> getPendingTransaksi() {
    return transaksiBox.values
        .where((t) => t.statusSinkronisasi == 'pending')
        .toList();
  }

  List<TransaksiHiveModel> getPendingUpdateTransaksi() {
    return transaksiBox.values
        .where((t) => t.statusSinkronisasi == 'pending_update')
        .toList();
  }

  List<TransaksiHiveModel> getPendingDeleteTransaksi() {
    return transaksiBox.values
        .where((t) => t.statusSinkronisasi == 'pending_delete')
        .toList();
  }

  Future<void> clearAllData() async {
    await usersBox.clear();
    await petaniBox.clear();
    await komoditasBox.clear();
    await transaksiBox.clear();
    await notifikasiBox.clear();
    await settingsBox.clear();
  }

  Future<void> repairBoxes() async {
    try {
      await init();
    } catch (e) {
      debugPrint("🚨 [HiveService] Gagal merepair box: $e");
      await Hive.deleteBoxFromDisk(_transaksiBoxName);
      await init();
    }
  }

  List<Map<String, dynamic>> exportTransaksiToJson() {
    return transaksiBox.values.map((t) => {
      'idLokal': t.idLokal,
      'petani': t.namaPetani,
      'komoditas': t.namaKomoditas,
      'total': t.totalBayar,
      'status': t.statusSinkronisasi,
    }).toList();
  }
}