import 'package:flutter/material.dart';
import '../../../../models/hive/transaksi_hive_model.dart';
import '../../../../services/master_data_service.dart';
import '../../../../services/saldo/kasbon_rules.dart';

class ManajerPetaController extends ChangeNotifier {
  final _svc = MasterDataService();

  String _filterKomoditas = 'Semua';
  String _filterGrade = 'Semua';

  String get filterKomoditas => _filterKomoditas;
  String get filterGrade => _filterGrade;

  void setFilterKomoditas(String komoditas) {
    _filterKomoditas = komoditas;
    notifyListeners();
  }

  void setFilterGrade(String grade) {
    _filterGrade = grade;
    notifyListeners();
  }

  // Mengambil daftar komoditas unik dari seluruh transaksi yang valid lokasi GPS-nya.
  // Pencairan kasbon bukan komoditas, jadi tidak menjadi pilihan filter.
  List<String> get daftarKomoditasUnik {
    final list = _svc.getRiwayatTransaksi()
        .where((t) => t.punyaLokasi)
        .where((t) => !KasbonRules.isPencairan(t.namaKomoditas))
        .map((t) => t.namaKomoditas)
        .toSet()
        .toList();
    list.sort();
    return ['Semua', ...list];
  }

  // Mengambil daftar transaksi yang difilter dan memiliki titik koordinat GPS valid
  List<TransaksiHiveModel> get getTransaksiDenganLokasi {
    return _svc.getRiwayatTransaksi().where((trx) {
      // 1. Validasi keberadaan koordinat GPS sah
      // Null (GPS gagal) atau 0,0 (penanda data lama) tidak punya titik.
      if (!trx.punyaLokasi) return false;

      // 2. Filter Komoditas
      if (_filterKomoditas != 'Semua' && trx.namaKomoditas != _filterKomoditas) {
        return false;
      }

      // 3. Filter Grade Kualitas
      if (_filterGrade != 'Semua' && trx.gradeTerpilih != _filterGrade) {
        return false;
      }

      return true;
    }).toList();
  }

  // Total volume panen (kg) dari titik yang sedang aktif di peta
  double get totalVolumeAktif {
    return getTransaksiDenganLokasi.fold(0.0, (sum, item) => sum + item.berat);
  }

  // Total valuasi pembelian (Rp) dari titik yang sedang aktif di peta. Pencairan
  // kasbon adalah uang keluar, bukan nilai panen.
  double get totalValuasiAktif {
    return getTransaksiDenganLokasi
        .where((t) => !KasbonRules.isPencairan(t.namaKomoditas))
        .fold(0.0, (sum, item) => sum + item.totalBayar);
  }
}