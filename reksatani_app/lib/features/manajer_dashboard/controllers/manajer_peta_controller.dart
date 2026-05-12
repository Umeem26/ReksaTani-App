import 'package:flutter/material.dart';
import '../../../../models/hive/transaksi_hive_model.dart';
import '../../../../services/master_data_service.dart';

class ManajerPetaController extends ChangeNotifier {
  final _svc = MasterDataService();

  List<TransaksiHiveModel> get getTransaksiDenganLokasi {
    // Hanya ambil transaksi yang titik kordinatnya berhasil direkam (bukan 0.0)
    return _svc.getRiwayatTransaksi().where((trx) =>
        trx.latitude != 0.0 && trx.longitude != 0.0).toList();
  }
}