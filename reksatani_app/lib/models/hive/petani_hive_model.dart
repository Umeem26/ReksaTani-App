import 'package:hive/hive.dart';

part 'petani_hive_model.g.dart';

@HiveType(typeId: 1)
class PetaniHiveModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String namaPetani;

  @HiveField(2)
  String desa;

  @HiveField(3)
  String pengepulId;

  @HiveField(4)
  double sisaHutangKasbon;

  @HiveField(5)
  DateTime waktuDibuat;

  PetaniHiveModel({
    required this.id,
    required this.namaPetani,
    required this.desa,
    required this.pengepulId,
    required this.sisaHutangKasbon,
    required this.waktuDibuat,
  });
}
