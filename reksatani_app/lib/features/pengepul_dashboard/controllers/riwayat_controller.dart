import 'package:flutter/material.dart';
import '../../../../models/hive/transaksi_hive_model.dart';
import '../../../../services/hive_service.dart';
import '../../../../services/master_data_service.dart';

class RiwayatController extends ChangeNotifier {
  final _svc  = MasterDataService();
  final _hive = HiveService();

  String _searchQuery = '';
  String _filterStatus = 'Semua'; 

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

  Future<void> hapusTransaksi(TransaksiHiveModel trx) async {
    if (trx.nominalPotongKasbon > 0 && trx.petaniId.isNotEmpty) {
      try {
        final petani = _hive.petaniBox.values.firstWhere((p) => p.id == trx.petaniId);
        petani.sisaHutangKasbon += trx.nominalPotongKasbon;
        await petani.save();
      } catch (_) {}
    }

    final uangTunaiKeluar = trx.totalBayar - trx.nominalPotongKasbon;
    if (uangTunaiKeluar > 0) {
      final user = _hive.usersBox.get('currentUser');
      if (user != null) {
        user.sisaUangJalan += uangTunaiKeluar;
        await user.save();
      }
    }

    if (trx.statusSinkronisasi == 'pending') {
      await _hive.transaksiBox.delete(trx.idLokal);
    } else if (trx.statusSinkronisasi == 'synced' || trx.statusSinkronisasi == 'pending_update') {
      trx.statusSinkronisasi = 'pending_delete';
      await trx.save();
    }
    notifyListeners();
  }
}