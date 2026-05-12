import 'package:flutter/material.dart';
import '../../../models/hive/transaksi_hive_model.dart';
import '../../../models/hive/user_hive_model.dart';
import '../../../services/hive_service.dart';
import '../../../services/master_data_service.dart';

/// Controller untuk BerandaManajerScreen.
/// Memisahkan logika bisnis dari UI (SRP).
class ManajerBerandaController extends ChangeNotifier {
  final _hive = HiveService();
  final _svc  = MasterDataService();

  bool syncing = false;

  UserHiveModel get user => _hive.usersBox.get('currentUser')!;
  
  List<UserHiveModel> get daftarAgen => _svc.getDaftarAgen();

  List<TransaksiHiveModel> get semuaTransaksi =>
      _svc.getRiwayatTransaksi();

  double get totalStokKg =>
      semuaTransaksi.fold(0, (sum, t) => sum + t.berat);

  double get totalNilai =>
      semuaTransaksi.fold(0, (sum, t) => sum + t.totalBayar);

  List<TransaksiHiveModel> getTransaksiAgen(String pengepulId) {
    return semuaTransaksi.where((t) => t.pengepulId == pengepulId).take(5).toList();
  }

  DateTime? getWaktuSyncTerakhir(String pengepulId) {
    final synced = semuaTransaksi
        .where((t) => t.pengepulId == pengepulId && t.waktuDisinkron != null)
        .toList();
    if (synced.isEmpty) return null;
    
    // Sortir berdasarkan waktu sinkronisasi (terbaru ke terlama)
    synced.sort((a, b) => b.waktuDisinkron!.compareTo(a.waktuDisinkron!));
    
    return synced.first.waktuDisinkron;
  }

  int get jumlahPending =>
      semuaTransaksi.where((t) => t.statusSinkronisasi == 'pending').length;

  int get jumlahSynced => semuaTransaksi.length - jumlahPending;

  Future<void> refresh() async {
    syncing = true;
    notifyListeners();
    await _svc.syncAll();
    syncing = false;
    notifyListeners();
  }
}