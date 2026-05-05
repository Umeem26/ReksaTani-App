import 'package:hive/hive.dart';

part 'komoditas_hive_model.g.dart';

@HiveType(typeId: 2)
class KomoditasHiveModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String namaKomoditas;

  @HiveField(2)
  String unitSatuan;

  @HiveField(3)
  List<Map<String, dynamic>> gradeKualitas;

  @HiveField(4)
  String diperbaruiOleh;

  @HiveField(5)
  DateTime waktuPembaruan;

  KomoditasHiveModel({
    required this.id,
    required this.namaKomoditas,
    required this.unitSatuan,
    required this.gradeKualitas,
    required this.diperbaruiOleh,
    required this.waktuPembaruan,
  });
}
