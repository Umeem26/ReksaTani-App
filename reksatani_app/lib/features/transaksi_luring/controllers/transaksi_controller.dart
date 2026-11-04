import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../../../../../models/hive/petani_hive_model.dart';
import '../../../../../models/hive/komoditas_hive_model.dart';
import '../../../../../models/hive/transaksi_hive_model.dart';
import '../../../../../services/hive_service.dart';
import '../../../../../services/saldo/kasbon_rules.dart';
import '../../../../../services/saldo/transaksi_ditolak.dart';
import '../../../../../services/sync/mongo_id.dart';
import 'package:reksatani_app/services/master_data_service.dart';

class TransaksiController {
  final _hive = HiveService();

  double get sisaUangJalan => _hive.usersBox.get('currentUser')?.sisaUangJalan ?? 0.0;

  List<PetaniHiveModel> get daftarPetani {
    final user = _hive.usersBox.get('currentUser');
    if (user == null) return [];
    return _hive.petaniAktif
        .where((p) => p.pengepulId == user.id)
        .toList();
  }
  List<KomoditasHiveModel> get daftarKomoditas {
    final allowedNames = {'gabah', 'kopi robusta', 'sawit'};
    return _hive.komoditasBox.values
        .where((k) => allowedNames.contains(k.namaKomoditas.toLowerCase()))
        .toList();
  }

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

  /// Parse angka dengan pemisah desimal titik atau koma ("12,5" / "12.5").
  static double? parseAngka(String text) {
    final t = text.trim().replaceAll(',', '.');
    if (t.isEmpty || t == '.') return null;
    return double.tryParse(t);
  }

  double getTotalBayar(String beratText, String hargaText) {
    final berat = parseAngka(beratText) ?? 0;
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
    final potongan = KasbonRules.potongan(
      sisaKasbon: petaniTerpilih?.sisaHutangKasbon ?? 0,
      totalBayar: totalBayar,
    );

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
      berat: parseAngka(beratText) ?? 0,
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

    final uangTunaiKeluar =
        KasbonRules.tunaiKeluar(totalBayar: totalBayar, potongan: potongan);
    if (uangTunaiKeluar > 0) {
      user.sisaUangJalan -= uangTunaiKeluar;
      await user.save();
    }

    // Sedikit delay agar animasi loading di layar terlihat natural
    await Future.delayed(const Duration(milliseconds: 400));
    MasterDataService().syncAll();
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
    if (KasbonRules.isPencairan(existingTrx.namaKomoditas)) {
      throw const TransaksiDitolak(
        'pencairan_tidak_bisa_diedit',
        'Pencairan kasbon tidak bisa diedit.',
      );
    }
    if (existingTrx.statusSinkronisasi == 'pending_delete') {
      throw const TransaksiDitolak(
        'sudah_dihapus',
        'Transaksi ini sedang menunggu dihapus.',
      );
    }

    final user = _hive.usersBox.get('currentUser')!;
    final petaniLama = _petaniDari(existingTrx);
    final efek = pratinjauEdit(
      existingTrx,
      petaniTerpilih: petaniTerpilih,
      totalBayar: totalBayar,
    );

    // Transaksi ditulis dulu. Bila aplikasi mati sebelum saldo tersimpan, sync
    // berikutnya memperbaiki saldo, karena transaksi adalah sumber kebenaran.
    existingTrx.petaniId        = petaniTerpilih?.id ?? '';
    existingTrx.namaPetani      = namaPenjual.trim();
    existingTrx.namaKomoditas   = komoditasTerpilih?.namaKomoditas ?? '';
    existingTrx.gradeTerpilih   = gradeTerpilih ?? '';
    existingTrx.berat           = parseAngka(beratText) ?? 0;
    existingTrx.hargaBeliSatuan = double.tryParse(hargaText) ?? 0;
    existingTrx.totalBayar      = totalBayar;
    existingTrx.nominalPotongKasbon = efek.potonganBaru;

    if (fotoNotaPath.isNotEmpty) existingTrx.fotoNota = fotoNotaPath;
    if (fotoBarangPath.isNotEmpty) existingTrx.fotoFisikBarang = fotoBarangPath;
    
    // GPS tidak di-update di sini untuk mempertahankan lokasi asli saat transaksi dibuat.
    
    if (existingTrx.statusSinkronisasi == 'synced') {
      existingTrx.statusSinkronisasi = 'pending_update';
    }

    await existingTrx.save();

    final kasbonLama = efek.kasbonPetaniLama;
    if (petaniLama != null && kasbonLama != null) {
      petaniLama.sisaHutangKasbon = kasbonLama;
      await petaniLama.save();
    }
    final kasbonBaru = efek.kasbonPetaniBaru;
    if (petaniTerpilih != null && kasbonBaru != null) {
      petaniTerpilih.sisaHutangKasbon = kasbonBaru;
      await petaniTerpilih.save();
    }
    if (MongoId.sama(existingTrx.pengepulId, user.id)) {
      user.sisaUangJalan = efek.uangJalan;
      await user.save();
    }

    await Future.delayed(const Duration(milliseconds: 400));
    MasterDataService().syncAll();
  }

  /// Keadaan saldo bila [trx] diedit, tanpa menulis apa pun. Dipakai layar untuk
  /// memeriksa kecukupan kas: pembanding yang benar adalah kas sesudah tunai
  /// lama dikembalikan, bukan kas sekarang.
  EfekEdit pratinjauEdit(
    TransaksiHiveModel trx, {
    required PetaniHiveModel? petaniTerpilih,
    required double totalBayar,
  }) {
    final petaniSama =
        petaniTerpilih != null && MongoId.sama(petaniTerpilih.id, trx.petaniId);
    final petaniLama = petaniSama ? petaniTerpilih : _petaniDari(trx);
    return KasbonRules.hitungEdit(
      totalLama: trx.totalBayar,
      potonganLama: trx.nominalPotongKasbon,
      totalBaru: totalBayar,
      uangJalan: sisaUangJalan,
      petaniSama: petaniSama,
      kasbonPetaniLama: petaniLama?.sisaHutangKasbon,
      kasbonPetaniBaru: petaniTerpilih?.sisaHutangKasbon,
    );
  }

  PetaniHiveModel? _petaniDari(TransaksiHiveModel trx) =>
      trx.petaniId.isEmpty ? null : _hive.petaniBox.get(MongoId.kanonik(trx.petaniId));

  Future<void> simpanKasbonMurni({
    required PetaniHiveModel petaniTerpilih,
    required String nominalKasbonText,
  }) async {
    final user = _hive.usersBox.get('currentUser')!;
    final now  = DateTime.now();
    final double nominalKasbon = double.tryParse(nominalKasbonText) ?? 0.0;

    // Ambil koordinat GPS murni luring untuk mencatat lokasi pencairan uang
    final koordinat = await _getKoordinatGPS();

    // 1. Catat kasbon ke riwayat transaksi sebagai bukti pengeluaran kas luring
    final trx = TransaksiHiveModel(
      idLokal: 'kasbon_${user.id}_${now.millisecondsSinceEpoch}',
      pengepulId: user.id,
      petaniId: petaniTerpilih.id,
      namaPengepul: user.username,
      namaPetani: petaniTerpilih.namaPetani.trim(),
      namaKomoditas: KasbonRules.labelPencairan,
      gradeTerpilih: '-',
      berat: 0,
      hargaBeliSatuan: 0,
      nominalPotongKasbon: 0, // 0 karena ini menambah hutang, bukan memotong/melunasi hasil panen
      totalBayar: nominalKasbon,
      fotoFisikBarang: '',
      fotoNota: '',
      latitude: koordinat['lat'] ?? 0.0,
      longitude: koordinat['lng'] ?? 0.0,
      statusSinkronisasi: 'pending',
      createdAt: now,
    );

    await _hive.saveTransaksi(trx);

    // 2. Tambahkan nominal kasbon baru ke akumulasi sisa hutang petani di Hive
    petaniTerpilih.sisaHutangKasbon += nominalKasbon;
    await petaniTerpilih.save();

    // 3. Potong langsung dari kas Saldo Uang Jalan milik pengepul saat ini
    user.sisaUangJalan -= nominalKasbon;
    await user.save();

    await Future.delayed(const Duration(milliseconds: 400));
    MasterDataService().syncAll();
  }
}