import '../../../../../models/hive/user_hive_model.dart';
import '../../../../../models/hive/transaksi_hive_model.dart';
import '../../../../../models/hive/petani_hive_model.dart';
import '../../../../../services/hive_service.dart';
import '../../../../../services/master_data_service.dart';
import '../../auth/controllers/auth_controller.dart';

class BerandaController {
  final _svc  = MasterDataService();
  final _hive = HiveService();

  UserHiveModel get user => _hive.usersBox.get('currentUser')!;
  
  int get jumlahTransaksi => _hive.transaksiBox.length;
  double get totalBerat => _svc.totalBeratHariIni;
  int get pending => _svc.jumlahPending;

  List<Map<String, dynamic>> get hargaTerbaru => _svc.getDaftarHargaDisplay().take(3).toList();
  List<TransaksiHiveModel> get riwayatTerbaru => _svc.getRiwayatTransaksi().take(3).toList();
  List<PetaniHiveModel> get mitraTerbaru {
    final userId = user.id;
    return _hive.petaniBox.values
        .where((p) => p.pengepulId == userId)
        .toList()
        .reversed
        .take(3)
        .toList();
  }

  Future<void> syncData() async {
    await _svc.syncAll();
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
  }

  Future<void> logout() async {
    await AuthController().logout();
  }
}
