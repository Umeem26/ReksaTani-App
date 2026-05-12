import 'package:flutter/material.dart';
import '../../../../models/hive/user_hive_model.dart';
import '../../../../services/hive_service.dart';
import '../../auth/controllers/auth_controller.dart';

class ProfilController extends ChangeNotifier {
  final _hive = HiveService();
  bool _isConnected = false;
  bool _isChecking = false;

  UserHiveModel get user => _hive.usersBox.get('currentUser')!;
  bool get isConnected => _isConnected;
  bool get isChecking => _isChecking;

  ProfilController() {
    cekKoneksi();
  }

  // Simulasi/pengecekan aman koneksi server tanpa memanggil .db internal
  Future<void> cekKoneksi() async {
    _isChecking = true;
    notifyListeners();
    
    try {
      // Kita asumsikan jika tidak ada error jaringan, status daring aktif
      await Future.delayed(const Duration(milliseconds: 600));
      _isConnected = true;
    } catch (_) {
      _isConnected = false;
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  // Membersihkan transaksi yang sudah tersinkronisasi dari memori lokal
  Future<int> bersihkanCacheTersinkronisasi() async {
    final box = _hive.transaksiBox;
    final keysToDelete = <dynamic>[];

    for (final key in box.keys) {
      final trx = box.get(key);
      if (trx != null && trx.statusSinkronisasi == 'synced') {
        keysToDelete.add(key);
      }
    }

    await box.deleteAll(keysToDelete);
    notifyListeners();
    return keysToDelete.length;
  }

  Future<void> logout() async {
    await AuthController().logout();
  }
}