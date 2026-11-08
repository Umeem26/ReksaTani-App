import 'package:hive/hive.dart';

part 'notifikasi_hive_model.g.dart';

@HiveType(typeId: 4)
class NotifikasiHiveModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String judul;

  @HiveField(2)
  String pesan;

  @HiveField(3)
  DateTime waktu;

  @HiveField(4)
  bool isRead;

  @HiveField(5)
  String tipe; // 'sync', 'saldo', 'harga', 'info'

  NotifikasiHiveModel({
    required this.id,
    required this.judul,
    required this.pesan,
    required this.waktu,
    this.isRead = false,
    required this.tipe,
  });
}
