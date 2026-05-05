import '../../../services/hive_service.dart';

class HargaItem {
  final String namaKomoditas;
  final String unitSatuan;
  final String grade;
  final double hargaMaks;

  const HargaItem({
    required this.namaKomoditas,
    required this.unitSatuan,
    required this.grade,
    required this.hargaMaks,
  });
}

class PasarController {
  final _hive = HiveService();
  String filterGrade = 'Semua';

  void setFilterGrade(String grade) {
    filterGrade = grade;
  }

  List<HargaItem> get daftarHarga {
    final result = <HargaItem>[];
    for (final k in _hive.komoditasBox.values) {
      for (final g in k.gradeKualitas) {
        final grade    = g['grade'] as String? ?? '';
        final hargaMaks = (g['harga_maks'] as num?)?.toDouble() ?? 0;
        if (filterGrade == 'Semua' || filterGrade == grade) {
          result.add(HargaItem(
            namaKomoditas: k.namaKomoditas,
            unitSatuan: k.unitSatuan,
            grade: grade,
            hargaMaks: hargaMaks,
          ));
        }
      }
    }
    return result;
  }
}
