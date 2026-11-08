import 'package:flutter/material.dart';
import '../../../../models/hive/transaksi_hive_model.dart';
import '../../../../services/master_data_service.dart';
import '../../../../services/saldo/transaksi_ledger_service.dart';

class RiwayatController extends ChangeNotifier {
  final _svc  = MasterDataService();
  final _ledger = TransaksiLedgerService();

  String _searchQuery = '';
  String _filterStatus = 'Semua'; 

  RiwayatController() {
    _svc.addListener(_onMasterDataChanged);
  }

  void _onMasterDataChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    _svc.removeListener(_onMasterDataChanged);
    super.dispose();
  }

  String get searchQuery => _searchQuery;
  String get filterStatus => _filterStatus;

  void setSearchQuery(String query) {
    _searchQuery = query.toLowerCase();
    notifyListeners();
  }

  void setFilterStatus(String status) {
    _filterStatus = status;
    notifyListeners();
  }

  List<TransaksiHiveModel> get filteredTransaksi {
    final list = _svc.getRiwayatTransaksi();

    return list.where((trx) {
      // 1. Filter Status
      if (_filterStatus == 'Pending') {
        if (trx.statusSinkronisasi == 'synced') return false;
      } else if (_filterStatus == 'Synced') {
        if (trx.statusSinkronisasi != 'synced') return false;
      }

      // 2. Filter Search (Nama Petani atau Komoditas)
      if (_searchQuery.isNotEmpty) {
        final matchNama = trx.namaPetani.toLowerCase().contains(_searchQuery);
        final matchKomoditas = trx.namaKomoditas.toLowerCase().contains(_searchQuery);
        return matchNama || matchKomoditas;
      }

      return true;
    }).toList();
  }

  /// Melempar `TransaksiDitolak` bila aturan uang menolaknya.
  Future<void> hapusTransaksi(TransaksiHiveModel trx) async {
    await _ledger.hapus(trx);
    notifyListeners();
    _svc.syncAll();
  }
}