import '../../../../../models/hive/user_hive_model.dart';
import '../../../../../models/hive/transaksi_hive_model.dart';
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

  Future<void> syncData() async {
    await _svc.syncAll();
  }

  Future<void> logout() async {
    await AuthController().logout();
  }
}
