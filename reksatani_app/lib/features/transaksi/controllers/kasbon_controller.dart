import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../models/hive/petani_hive_model.dart';
import '../../../models/hive/user_hive_model.dart';

class KasbonController extends ChangeNotifier {
  PetaniHiveModel? _selectedPetani;
  double _berat = 0.0;
  double _hargaPerKg = 0.0;
  String? _selectedGrade;
  String? _imagePath;
  double _uangJalanAgen = 0.0;

  PetaniHiveModel? get selectedPetani => _selectedPetani;
  double get berat => _berat;
  double get hargaPerKg => _hargaPerKg;
  String? get selectedGrade => _selectedGrade;
  String? get imagePath => _imagePath;
  double get uangJalanAgen => _uangJalanAgen;

  double get totalBayar => _berat * _hargaPerKg;
  
  double get sisaKasbonPetani {
    if (_selectedPetani == null) return 0.0;
    final sisa = _selectedPetani!.sisaHutangKasbon - totalBayar;
    return sisa < 0 ? 0 : sisa;
  }

  double get sisaUangJalanSetelah {
    return _uangJalanAgen - totalBayar;
  }

  bool get isValid => totalBayar <= _uangJalanAgen && _selectedPetani != null && _berat > 0;
  String? get error {
    if (_selectedPetani == null) return "Pilih petani terlebih dahulu";
    if (totalBayar > _uangJalanAgen) return "Uang jalan agen tidak mencukupi!";
    if (_berat <= 0) return "Berat harus lebih dari 0";
    return null;
  }

  Future<void> init(String currentUserId) async {
    final userBox = Hive.box<UserHiveModel>('user_box');
    final user = userBox.get(currentUserId);
    if (user != null) {
      _uangJalanAgen = user.sisaUangJalan;
    }
    notifyListeners();
  }

  void injectAutoFillData({
    required String imagePath,
    required double berat,
    required double hargaPerKg,
    required String grade,
  }) {
    _imagePath = imagePath;
    _berat = berat;
    _hargaPerKg = hargaPerKg;
    _selectedGrade = grade;
    notifyListeners();
  }

  void setSelectedPetani(PetaniHiveModel? petani) {
    _selectedPetani = petani;
    notifyListeners();
  }

  void setBerat(double value) {
    _berat = value;
    notifyListeners();
  }

  void setHargaPerKg(double value) {
    _hargaPerKg = value;
    notifyListeners();
  }

  void setGrade(String grade) {
    _selectedGrade = grade;
    notifyListeners();
  }

  Future<bool> submitTransaction() async {
    if (!isValid) return false;

    try {
      if (_selectedPetani != null) {
        _selectedPetani!.sisaHutangKasbon = sisaKasbonPetani;
        await _selectedPetani!.save();
      }

      return true;
    } catch (e) {
      debugPrint("🚨 Error submit transaksi: $e");
      return false;
    }
  }
}
