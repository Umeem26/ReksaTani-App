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

  List<TransaksiHiveModel> get semuaTransaksi =>
      _svc.getRiwayatTransaksi();

  double get totalStokKg =>
      semuaTransaksi.fold(0, (sum, t) => sum + t.berat);

  double get totalNilai =>
      semuaTransaksi.fold(0, (sum, t) => sum + t.totalBayar);

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