import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../../models/hive/user_hive_model.dart';
import '../../../../services/hive_service.dart';
import '../../../../services/mongodb_service.dart';
import '../../../../services/master_data_service.dart';
import '../../auth/controllers/auth_controller.dart';

class ProfilController extends ChangeNotifier {
  final _hive = HiveService();
  bool _isConnected = false;
  bool _isChecking = false;
  late final StreamSubscription<List<ConnectivityResult>> _connectivitySub;

  UserHiveModel get user => _hive.usersBox.get('currentUser')!;
  bool get isConnected => _isConnected;
  bool get isChecking => _isChecking;

  ProfilController() {
    cekKoneksi();
    MasterDataService().addListener(_onMasterDataChanged);
    _connectivitySub = Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);
  }

  void _onMasterDataChanged() {
    notifyListeners();
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final online = results.any((r) => r != ConnectivityResult.none);
    _isConnected = online;
    notifyListeners();
  }

  @override
  void dispose() {
    MasterDataService().removeListener(_onMasterDataChanged);
    _connectivitySub.cancel();
    super.dispose();
  }

  Future<void> cekKoneksi() async {
    _isChecking = true;
    notifyListeners();
    
    try {
      _isConnected = await MongoDatabase.ping();
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