import '../../../../../models/hive/user_hive_model.dart';
import '../../../../../models/hive/transaksi_hive_model.dart';
import '../../../../../models/hive/petani_hive_model.dart';
import '../../../../../services/hive_service.dart';
import '../../../../../services/master_data_service.dart';
import '../../../../../services/saldo/kasbon_rules.dart';
import '../../../../../services/saldo/transaksi_ledger_service.dart';
import '../../auth/controllers/auth_controller.dart';

class BerandaController {
  final _svc  = MasterDataService();
  final _hive = HiveService();
  final _ledger = TransaksiLedgerService();

  UserHiveModel get user => _hive.usersBox.get('currentUser')!;

  int get jumlahTransaksi => _svc.getRiwayatTransaksi().length;
  double get totalBerat => _svc.totalBeratHariIni;
  int get pending => _svc.jumlahPending;

  double get totalPengeluaranHariIni {
    final today = DateTime.now();
    final userId = user.id;
    return _hive.transaksiBox.values
        .where((t) =>
            t.pengepulId == userId &&
            t.createdAt.year == today.year &&
            t.createdAt.month == today.month &&
            t.createdAt.day == today.day &&
            t.statusSinkronisasi != 'pending_delete')
        .fold(
          0.0,
          (s, t) =>
              s +
              KasbonRules.tunaiKeluar(
                totalBayar: t.totalBayar,
                potongan: t.nominalPotongKasbon,
              ),
        );
  }

  double get totalPotonganKasbonHariIni {
    final today = DateTime.now();
    final userId = user.id;
    return _hive.transaksiBox.values
        .where((t) =>
            t.pengepulId == userId &&
            t.createdAt.year == today.year &&
            t.createdAt.month == today.month &&
            t.createdAt.day == today.day &&
            t.statusSinkronisasi != 'pending_delete')
        .fold(0.0, (s, t) => s + t.nominalPotongKasbon);
  }

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

  /// Melempar `TransaksiDitolak` bila aturan uang menolaknya.
  Future<void> hapusTransaksi(TransaksiHiveModel trx) async {
    await _ledger.hapus(trx);
    _svc.syncAll();
  }

  Future<void> logout() async {
    await AuthController().logout();
  }
}
