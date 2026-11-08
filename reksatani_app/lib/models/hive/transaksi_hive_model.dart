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

  /// Null bila GPS gagal. Data lama memakai 0,0 sebagai penanda yang sama.
  @HiveField(14)
  double? latitude;

  @HiveField(15)
  double? longitude;

  @HiveField(16)
  String statusSinkronisasi; 

  @HiveField(17)
  DateTime createdAt;

  @HiveField(18)
  DateTime? waktuDisinkron;

  @HiveField(19)
  double? skorKeyakinan;

  @HiveField(20, defaultValue: false)
  bool isManualGrading;

  /// `pending`: perangkat ini masih harus mengunggah foto.
  /// `hilang`: file foto lokal sudah tidak ada.
  /// `dilewati`: disimpan tanpa foto lengkap, atas izin agen.
  /// `menunggu_asal`: baris hasil pull, perangkat asal masih mengunggahnya.
  /// `ok`: selain itu.
  @HiveField(21, defaultValue: 'ok')
  String statusFoto;

  /// Label router yang disarankan AI ('gabah', 'kelapa_sawit', 'kopi'), atau
  /// null bila tidak ada saran. Tetap tersimpan walau pengguna memilih lain.
  @HiveField(22, defaultValue: null)
  String? saranKomoditasAi;

  /// True bila komoditas akhir berbeda dari [saranKomoditasAi].
  @HiveField(23, defaultValue: false)
  bool komoditasDiubahPengguna;

  /// Versi rubrik yang menghasilkan [gradeTerpilih]; null untuk data lama.
  @HiveField(24, defaultValue: null)
  String? rubrikVersi;

  /// Jawaban checklist sebagai `pertanyaan=opsi`; null untuk data lama.
  @HiveField(25, defaultValue: null)
  List<String>? rubrikJawaban;

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
    this.skorKeyakinan,
    this.isManualGrading = false,
    this.statusFoto = 'ok',
    this.saranKomoditasAi,
    this.komoditasDiubahPengguna = false,
    this.rubrikVersi,
    this.rubrikJawaban,
  });

  /// True bila koordinat bisa dipakai peta: tidak null dan bukan penanda 0,0
  /// milik data lama.
  bool get punyaLokasi {
    final lat = latitude, lng = longitude;
    return lat != null && lng != null && lat != 0.0 && lng != 0.0;
  }
}
