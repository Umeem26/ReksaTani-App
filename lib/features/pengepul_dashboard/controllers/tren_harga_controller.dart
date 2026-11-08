import 'package:flutter/material.dart';
import '../../../../services/hive_service.dart';
import '../../../../services/master_data_service.dart';

class DataTrenItem {
  final String namaKomoditas;
  final String grade;
  final String satuan;

  /// `harga_maks` yang berlaku sekarang.
  final double hargaSaatIni;

  DataTrenItem({
    required this.namaKomoditas,
    required this.grade,
    required this.satuan,
    required this.hargaSaatIni,
  });
}

/// Harga per grade saat ini.
///
/// Aplikasi hanya menyimpan `harga_maks` terakhir, jadi tidak ada riwayat harga
/// yang bisa digambar. Grafik baru boleh kembali setelah riwayat harga nyata
/// tersimpan; jangan membentuknya dari harga sekarang.
class TrenHargaController extends ChangeNotifier {
  static const String labelTanpaRiwayat = 'Riwayat harga belum tersedia';

  final _hive = HiveService();
  List<DataTrenItem> _daftarTren = [];
  int _selectedIndex = 0;

  List<DataTrenItem> get daftarTren => _daftarTren;
  int get selectedIndex => _selectedIndex;

  DataTrenItem? get itemTerpilih => _daftarTren.isNotEmpty ? _daftarTren[_selectedIndex] : null;

  TrenHargaController() {
    _muatDataTren();
    MasterDataService().addListener(_onMasterDataChanged);
  }

  void _onMasterDataChanged() {
    _muatDataTren();
  }

  @override
  void dispose() {
    MasterDataService().removeListener(_onMasterDataChanged);
    super.dispose();
  }

  void setSelectedIndex(int index) {
    _selectedIndex = index;
    notifyListeners();
  }

  void _muatDataTren() {
    final result = <DataTrenItem>[];

    // Iterasi komoditas yang ada di memori lokal
    for (final k in _hive.komoditasBox.values) {
      for (final g in k.gradeKualitas) {
        final grade = g['grade'] as String? ?? '';
        final hargaMaks = (g['harga_maks'] as num?)?.toDouble() ?? 0.0;

        if (hargaMaks > 0) {
          result.add(DataTrenItem(
            namaKomoditas: k.namaKomoditas,
            grade: grade,
            satuan: k.unitSatuan,
            hargaSaatIni: hargaMaks,
          ));
        }
      }
    }

    _daftarTren = result;
    notifyListeners();
  }
}
