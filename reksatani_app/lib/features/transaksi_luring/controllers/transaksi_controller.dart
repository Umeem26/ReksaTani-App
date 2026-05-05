import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../../../../../models/hive/petani_hive_model.dart';
import '../../../../../models/hive/komoditas_hive_model.dart';
import '../../../../../models/hive/transaksi_hive_model.dart';
import '../../../../../services/hive_service.dart';

class TransaksiController {
  final _hive = HiveService();

  List<PetaniHiveModel> get daftarPetani => _hive.petaniBox.values.toList();
  List<KomoditasHiveModel> get daftarKomoditas => _hive.komoditasBox.values.toList();

  List<Map<String, dynamic>> getDaftarGrade(KomoditasHiveModel? komoditas) {
    if (komoditas == null) return [];
    return komoditas.gradeKualitas;
  }

  double getHargaMaksGrade(KomoditasHiveModel? komoditas, String? gradeTerpilih) {
    final daftarGrade = getDaftarGrade(komoditas);
    if (gradeTerpilih == null || daftarGrade.isEmpty) return 0;
    final g = daftarGrade.firstWhere(
      (g) => g['grade'] == gradeTerpilih,
      orElse: () => <String, dynamic>{},
    );
    return (g['harga_maks'] as num?)?.toDouble() ?? 0;
  }

  double getTotalBayar(String beratText, String hargaText) {
    final berat = double.tryParse(beratText) ?? 0;
    final harga = double.tryParse(hargaText) ?? 0;
    return berat * harga;
  }

  bool isHargaMelebihi(KomoditasHiveModel? komoditas, String? gradeTerpilih, String hargaText) {
    final harga = double.tryParse(hargaText) ?? 0;
    final maks = getHargaMaksGrade(komoditas, gradeTerpilih);
    return maks > 0 && harga > maks;
  }

  // ─── FUNGSI BARU: MENGAMBIL KOORDINAT DENGAN TIMEOUT 7 DETIK ───
  Future<Map<String, double>> _getKoordinatGPS() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      // 1. Cek apakah GPS HP menyala
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return {'lat': 0.0, 'lng': 0.0};

      // 2. Cek apakah izin aplikasi diberikan
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return {'lat': 0.0, 'lng': 0.0};
      }
      
      if (permission == LocationPermission.deniedForever) {
        return {'lat': 0.0, 'lng': 0.0};
      }

      // 3. Ambil posisi dengan batas waktu maksimal 7 detik
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 7), 
      );

      return {'lat': position.latitude, 'lng': position.longitude};
    } catch (e) {
      // Jika TimeoutException (karena di kebun/susah sinyal), kembalikan 0.0
      return {'lat': 0.0, 'lng': 0.0};
    }
  }

  Future<void> simpanTransaksi({
    required PetaniHiveModel? petaniTerpilih,
    required String namaPenjual,
    required KomoditasHiveModel? komoditasTerpilih,
    required String? gradeTerpilih,
    required String beratText,
    required String hargaText,
    required double totalBayar,
    required String fotoNotaPath,
    required String fotoBarangPath,
  }) async {
    final user = _hive.usersBox.get('currentUser')!;
    final now  = DateTime.now();
    final sisaKasbon  = petaniTerpilih?.sisaHutangKasbon ?? 0;
    final potongan    = sisaKasbon > 0 ? sisaKasbon.clamp(0, totalBayar).toDouble() : 0.0;

    // Panggil pencarian GPS di sini
    final koordinat = await _getKoordinatGPS();

    final trx = TransaksiHiveModel(
      idLokal: '${user.id}_${now.millisecondsSinceEpoch}',
      pengepulId: user.id,
      petaniId: petaniTerpilih?.id ?? '',
      namaPengepul: user.username,
      namaPetani: namaPenjual.trim(),
      namaKomoditas: komoditasTerpilih?.namaKomoditas ?? '',
      gradeTerpilih: gradeTerpilih ?? '',
      berat: double.tryParse(beratText) ?? 0,
      hargaBeliSatuan: double.tryParse(hargaText) ?? 0,
      nominalPotongKasbon: potongan,
      totalBayar: totalBayar,
      fotoFisikBarang: fotoBarangPath,
      fotoNota: fotoNotaPath,
      // Masukkan hasil GPS ke model
      latitude: koordinat['lat'] ?? 0.0,
      longitude: koordinat['lng'] ?? 0.0,
      statusSinkronisasi: 'pending',
      createdAt: now,
    );

    await _hive.saveTransaksi(trx);

    if (petaniTerpilih != null && potongan > 0) {
      petaniTerpilih.sisaHutangKasbon =
          (petaniTerpilih.sisaHutangKasbon - potongan).clamp(0, double.infinity);
      await petaniTerpilih.save();
    }

    // Sedikit delay agar animasi loading di layar terlihat natural
    await Future.delayed(const Duration(milliseconds: 400));
  }

  Future<void> updateTransaksi(
    TransaksiHiveModel existingTrx, {
    required PetaniHiveModel? petaniTerpilih,
    required String namaPenjual,
    required KomoditasHiveModel? komoditasTerpilih,
    required String? gradeTerpilih,
    required String beratText,
    required String hargaText,
    required double totalBayar,
    required String fotoNotaPath,
    required String fotoBarangPath,
  }) async {
    existingTrx.petaniId        = petaniTerpilih?.id ?? '';
    existingTrx.namaPetani      = namaPenjual.trim();
    existingTrx.namaKomoditas   = komoditasTerpilih?.namaKomoditas ?? '';
    existingTrx.gradeTerpilih   = gradeTerpilih ?? '';
    existingTrx.berat           = double.tryParse(beratText) ?? 0;
    existingTrx.hargaBeliSatuan = double.tryParse(hargaText) ?? 0;
    existingTrx.totalBayar      = totalBayar;
    
    if (fotoNotaPath.isNotEmpty) existingTrx.fotoNota = fotoNotaPath;
    if (fotoBarangPath.isNotEmpty) existingTrx.fotoFisikBarang = fotoBarangPath;
    
    // GPS tidak di-update di sini untuk mempertahankan lokasi asli saat transaksi dibuat.
    
    if (existingTrx.statusSinkronisasi == 'synced') {
      existingTrx.statusSinkronisasi = 'pending_update';
    }

    await existingTrx.save();
    await Future.delayed(const Duration(milliseconds: 400));
  }

  Future<void> deleteTransaksi(TransaksiHiveModel trx) async {
    if (trx.statusSinkronisasi == 'pending') {
      await _hive.transaksiBox.delete(trx.idLokal);
    }
  }
}