import 'package:flutter/material.dart';
import '../../../../services/hive_service.dart';

class DataTrenItem {
  final String namaKomoditas;
  final String grade;
  final String satuan;
  final double hargaSaatIni;
  final List<double> riwayat7Hari; // Harga H-6 sampai H-0 (Hari ini)
  final double persentasePerubahan;
  final bool isNaik;

  DataTrenItem({
    required this.namaKomoditas,
    required this.grade,
    required this.satuan,
    required this.hargaSaatIni,
    required this.riwayat7Hari,
    required this.persentasePerubahan,
    required this.isNaik,
  });
}

class TrenHargaController extends ChangeNotifier {
  final _hive = HiveService();
  List<DataTrenItem> _daftarTren = [];
  int _selectedIndex = 0;

  List<DataTrenItem> get daftarTren => _daftarTren;
  int get selectedIndex => _selectedIndex;
  
  DataTrenItem? get itemTerpilih => _daftarTren.isNotEmpty ? _daftarTren[_selectedIndex] : null;

  TrenHargaController() {
    _muatDataTren();
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
          // Simulasi algoritma fluktuasi harga pasar 7 hari terakhir yang konsisten
          // Berbasis pada harga puncak hari ini
          final base = hargaMaks;
          final h1 = base * 0.91; // H-6
          final h2 = base * 0.94; // H-5
          final h3 = base * 0.92; // H-4
          final h4 = base * 0.96; // H-3
          final h5 = base * 0.98; // H-2
          final h6 = base * 0.99; // H-1
          final h7 = base;        // Hari ini
          
          final riwayat = [h1, h2, h3, h4, h5, h6, h7];
          
          // Kalkulasi persentase kenaikan/penurunan dari H-6 ke Hari ini
          final selisih = h7 - h1;
          final persen = (selisih / h1) * 100;

          result.add(DataTrenItem(
            namaKomoditas: k.namaKomoditas,
            grade: grade,
            satuan: k.unitSatuan,
            hargaSaatIni: hargaMaks,
            riwayat7Hari: riwayat,
            persentasePerubahan: persen.abs(),
            isNaik: selisih >= 0,
          ));
        }
      }
    }

    _daftarTren = result;
    notifyListeners();
  }
}