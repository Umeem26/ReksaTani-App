import 'package:hive_flutter/hive_flutter.dart';
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
  // 1. Tambahkan nama box khusus pengaturan/sesi
  static const String _settingsBoxName = 'settingsBox';

  Future<void> init() async {
    await Hive.initFlutter();

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

    await Hive.openBox<UserHiveModel>(_usersBoxName);
    await Hive.openBox<PetaniHiveModel>(_petaniBoxName);
    await Hive.openBox<KomoditasHiveModel>(_komoditasBoxName);
    await Hive.openBox<TransaksiHiveModel>(_transaksiBoxName);
    await Hive.openBox<NotifikasiHiveModel>('notifikasiBox');
    // 2. Buka box settings (tanpa tipe khusus agar bisa menampung tipe data dinamis)
    await Hive.openBox(_settingsBoxName);
  }

  Box<UserHiveModel> get usersBox => Hive.box<UserHiveModel>(_usersBoxName);
  Box<PetaniHiveModel> get petaniBox => Hive.box<PetaniHiveModel>(_petaniBoxName);
  Box<KomoditasHiveModel> get komoditasBox => Hive.box<KomoditasHiveModel>(_komoditasBoxName);
  Box<TransaksiHiveModel> get transaksiBox => Hive.box<TransaksiHiveModel>(_transaksiBoxName);
  Box<NotifikasiHiveModel> get notifikasiBox => Hive.box<NotifikasiHiveModel>('notifikasiBox');
  // 3. Buat getter untuk settingsBox
  Box get settingsBox => Hive.box(_settingsBoxName);
  
  bool isFirstTime() {
    // Jika 'hasOnboarded' bernilai false atau belum ada (null), berarti ini pertama kali
    final hasOnboarded = settingsBox.get('hasOnboarded', defaultValue: false);
    return !hasOnboarded;
  }

  /// Menandai bahwa user sudah selesai melewati layar Onboarding
  Future<void> completeOnboarding() async {
    await settingsBox.put('hasOnboarded', true);
  }

  // ═══════════════════════════════════════════════════════════════
  // LOGIKA TRANSAKSI & DATA
  // ═══════════════════════════════════════════════════════════════

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
  }
}