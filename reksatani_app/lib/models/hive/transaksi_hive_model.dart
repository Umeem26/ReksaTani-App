import 'package:hive/hive.dart';

part 'transaksi_hive_model.g.dart';

@HiveType(typeId: 3)
class TransaksiHiveModel extends HiveObject {
  @HiveField(0)
  String idLokal;

  @HiveField(1)
  String? id;

  @HiveField(2)
  String pengepulId;

  @HiveField(3)
  String petaniId;

  @HiveField(4)
  String namaPengepul;

  @HiveField(5)
  String namaPetani;

  @HiveField(6)
  String namaKomoditas;

  @HiveField(7)
  String gradeTerpilih;

  @HiveField(8)
  double berat;

  @HiveField(9)
  double hargaBeliSatuan;

  @HiveField(10)
  double nominalPotongKasbon;

  @HiveField(11)
  double totalBayar;

  @HiveField(12)
  String fotoFisikBarang; 

  @HiveField(13)
  String fotoNota; 

  @HiveField(14)
  double latitude;

  @HiveField(15)
  double longitude;

  @HiveField(16)
  String statusSinkronisasi; 

  @HiveField(17)
  DateTime createdAt;

  @HiveField(18)
  DateTime? waktuDisinkron;

  TransaksiHiveModel({
    required this.idLokal,
    this.id,
    required this.pengepulId,
    required this.petaniId,
    required this.namaPengepul,
    required this.namaPetani,
    required this.namaKomoditas,
    required this.gradeTerpilih,
    required this.berat,
    required this.hargaBeliSatuan,
    required this.nominalPotongKasbon,
    required this.totalBayar,
    required this.fotoFisikBarang,
    required this.fotoNota,
    required this.latitude,
    required this.longitude,
    required this.statusSinkronisasi,
    required this.createdAt,
    this.waktuDisinkron,
  });
}
