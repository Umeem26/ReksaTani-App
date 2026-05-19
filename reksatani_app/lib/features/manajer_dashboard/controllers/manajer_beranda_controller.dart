import 'package:flutter/material.dart';
import '../../../models/hive/komoditas_hive_model.dart';
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
  List<KomoditasHiveModel> get daftarKomoditas => _svc.getDaftarKomoditas();

  List<TransaksiHiveModel> get semuaTransaksi =>
      _svc.getRiwayatTransaksi();

  double get totalStokKg =>
      semuaTransaksi.fold(0, (sum, t) => sum + t.berat);

  double get totalNilai =>
      semuaTransaksi.fold(0, (sum, t) => sum + t.totalBayar);

  Map<String, double> get stokPerKomoditas {
    final Map<String, double> hasil = {};
    for (var t in semuaTransaksi) {
      hasil[t.namaKomoditas] = (hasil[t.namaKomoditas] ?? 0) + t.berat;
    }
    return hasil;
  }

  List<TransaksiHiveModel> getTransaksiAgen(String pengepulId) {
    return semuaTransaksi.where((t) => t.pengepulId == pengepulId).take(5).toList();
  }

  DateTime? getWaktuSyncTerakhir(String pengepulId) {
    final trxAgen = semuaTransaksi.where((t) => t.pengepulId == pengepulId).toList();
    if (trxAgen.isEmpty) return null;

    DateTime? terbaru;
    for (var t in trxAgen) {
      if (terbaru == null || t.createdAt.isAfter(terbaru)) {
        terbaru = t.createdAt;
      }
      if (t.waktuDisinkron != null) {
        if (terbaru == null || t.waktuDisinkron!.isAfter(terbaru)) {
          terbaru = t.waktuDisinkron;
        }
      }
    }
    return terbaru;
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