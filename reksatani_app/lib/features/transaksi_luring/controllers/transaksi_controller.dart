import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../../../../../models/hive/petani_hive_model.dart';
import '../../../../../models/hive/komoditas_hive_model.dart';
import '../../../../../models/hive/transaksi_hive_model.dart';
import '../../../../../services/foto/foto_tertunda.dart';
import '../../../../../services/hive_service.dart';
import '../../../../../services/saldo/kasbon_rules.dart';
import '../../../../../services/saldo/transaksi_ditolak.dart';
import '../../../../../services/sync/mongo_id.dart';
import '../../pcd_scanner/services/commodity_mapper.dart';
import '../../pcd_scanner/services/grading_rubric.dart';
import 'package:reksatani_app/services/master_data_service.dart';

/// Mengambil koordinat saat ini, atau null bila lokasi tidak bisa didapat.
typedef AmbilLokasi = Future<({double lat, double lng})?> Function();

/// Asal grade dan komoditas sebuah transaksi: saran AI (bila ada) dan jawaban
/// checklist rubrik. Versi rubrik dicap controller, bukan dari luar.
class CatatanGrading {
  /// Label router, misalnya 'kelapa_sawit'. Null bila AI tidak memberi saran.
  final String? saranKomoditasAi;

  /// Jawaban `pertanyaan=opsi`. Null berarti checklist tidak diisi.
  final List<String>? rubrikJawaban;

  const CatatanGrading({this.saranKomoditasAi, this.rubrikJawaban});
}

class TransaksiController {
  TransaksiController({AmbilLokasi? ambilLokasi})
      : _ambilLokasi = ambilLokasi ?? _getKoordinatGPS;

  final AmbilLokasi _ambilLokasi;
  final _hive = HiveService();

  /// Pemberitahuan di layar bila penyimpanan mengembalikan "lokasi tidak tercatat".
  static const String pesanLokasiGagal =
      'Lokasi GPS tidak tercatat. Data tetap tersimpan, tetapi tidak muncul di peta manajer.';

  /// Penanda "lokasi tidak ada" di data, karena validator `transaksi` di Atlas hanya
  /// menerima angka untuk `latitude` dan `longitude`, bukan null. Peta manajer
  /// melewati titik bernilai ini.
  static const double _tanpaLokasi = 0.0;

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

  /// Satu-satunya rumus total. Dipakai untuk data dan untuk tampilan di layar.
  /// Dibulatkan ke dua desimal seperti saldo, supaya galat `double` tidak terbawa.
  double getTotalBayar(String beratText, String hargaText) {
    final berat = parseAngka(beratText) ?? 0;
    final harga = parseAngka(hargaText) ?? 0;
    return ((berat * harga) * 100).round() / 100;
  }

  bool isHargaMelebihi(KomoditasHiveModel? komoditas, String? gradeTerpilih, String hargaText) {
    final harga = parseAngka(hargaText) ?? 0;
    final maks = getHargaMaksGrade(komoditas, gradeTerpilih);
    return maks > 0 && harga > maks;
  }

  /// Menolak berat yang tidak bisa menjadi total yang sah.
  void _periksaBerat(String beratText) {
    final berat = parseAngka(beratText);
    if (berat == null || !berat.isFinite || berat <= 0) {
      throw const TransaksiDitolak('berat_tidak_sah', 'Berat harus lebih dari nol.');
    }
  }

  /// Aturan harga pembelian. Komoditas dan grade ikut diperiksa, karena tanpa
  /// keduanya batas harga bernilai 0, yang berarti tidak ada batas sama sekali.
  void _periksaHarga(
    KomoditasHiveModel? komoditas,
    String? grade,
    String hargaText,
  ) {
    if (komoditas == null) {
      throw const TransaksiDitolak('komoditas_kosong', 'Silakan pilih komoditas.');
    }
    if (!getDaftarGrade(komoditas).any((g) => g['grade'] == grade)) {
      throw const TransaksiDitolak('grade_tidak_dikenal', 'Silakan pilih grade kualitas.');
    }
    final harga = parseAngka(hargaText);
    if (harga == null || !harga.isFinite || harga <= 0) {
      throw const TransaksiDitolak('harga_tidak_sah', 'Harga harus lebih dari nol.');
    }
    if (isHargaMelebihi(komoditas, grade, hargaText)) {
      final maks = getHargaMaksGrade(komoditas, grade).toInt();
      throw TransaksiDitolak(
        'harga_melebihi',
        'Harga melebihi batas maksimal Grade $grade (Rp $maks).',
      );
    }
  }

  /// True bila komoditas akhir tidak cocok dengan saran AI. Tanpa saran,
  /// tidak ada yang diubah.
  static bool komoditasDiubah(String? saranAi, String namaKomoditas) {
    if (saranAi == null || saranAi.isEmpty) return false;
    return CommodityMapper.match<String>([namaKomoditas], (s) => s, saranAi) == null;
  }

  /// Bila checklist diisi, grade harus sama dengan hasil rubrik untuk komoditas
  /// itu. Grade ditentukan jawaban, bukan dikirim terpisah.
  void _periksaRubrik(
    KomoditasHiveModel? komoditas,
    String? grade,
    List<String>? jawaban,
  ) {
    if (jawaban == null) return;
    final rubrik = rubrikUntukKomoditas(komoditas?.namaKomoditas);
    if (rubrik == null || gradeDariJawaban(rubrik, bacaJawaban(jawaban)) != grade) {
      throw const TransaksiDitolak(
        'grade_tidak_cocok_rubrik',
        'Grade tidak sesuai jawaban checklist. Periksa lagi checklist kualitas.',
      );
    }
  }

  // ─── FUNGSI BARU: MENGAMBIL KOORDINAT DENGAN TIMEOUT 7 DETIK ───
  static Future<({double lat, double lng})?> _getKoordinatGPS() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      // 1. Cek apakah GPS HP menyala
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      // 2. Cek apakah izin aplikasi diberikan
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      // 3. Ambil posisi dengan batas waktu maksimal 7 detik
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 7),
      );

      return (lat: position.latitude, lng: position.longitude);
    } catch (e) {
      // Termasuk TimeoutException (karena di kebun/susah sinyal)
      return null;
    }
  }

  /// Total dihitung di sini dari berat dan harga, tidak diterima dari luar.
  ///
  /// Melempar [TransaksiDitolak] bila aturan dilanggar, sebelum ada yang ditulis.
  /// [izinkanTanpaFoto] adalah jawaban agen atas peringatan foto di layar.
  ///
  /// Mengembalikan true bila lokasi GPS tercatat. Gagalnya GPS tidak menggagalkan
  /// penyimpanan.
  Future<bool> simpanTransaksi({
    required PetaniHiveModel? petaniTerpilih,
    required String namaPenjual,
    required KomoditasHiveModel? komoditasTerpilih,
    required String? gradeTerpilih,
    required String beratText,
    required String hargaText,
    required String fotoNotaPath,
    required String fotoBarangPath,
    required bool izinkanTanpaFoto,
    CatatanGrading grading = const CatatanGrading(),
  }) async {
    final fotoKurang = fotoNotaPath.isEmpty || fotoBarangPath.isEmpty;
    if (fotoKurang && !izinkanTanpaFoto) {
      throw const TransaksiDitolak('foto_kurang', 'Foto nota atau barang belum ada.');
    }
    _periksaBerat(beratText);
    _periksaHarga(komoditasTerpilih, gradeTerpilih, hargaText);
    _periksaRubrik(komoditasTerpilih, gradeTerpilih, grading.rubrikJawaban);

    final totalBayar = getTotalBayar(beratText, hargaText);
    final user = _hive.usersBox.get('currentUser')!;
    final now  = DateTime.now();
    final potongan = KasbonRules.potongan(
      sisaKasbon: petaniTerpilih?.sisaHutangKasbon ?? 0,
      totalBayar: totalBayar,
    );

    // Panggil pencarian GPS di sini
    final koordinat = await _ambilLokasi();

    final idLokal = '${user.id}_${now.millisecondsSinceEpoch}';
    final fotoNota = await FotoTertunda.salin(fotoNotaPath, idLokal: idLokal, jenis: 'nota');
    final fotoBarang = await FotoTertunda.salin(fotoBarangPath, idLokal: idLokal, jenis: 'barang');

    final trx = TransaksiHiveModel(
      idLokal: idLokal,
      pengepulId: user.id,
      petaniId: petaniTerpilih?.id ?? '',
      namaPengepul: user.username,
      namaPetani: namaPenjual.trim(),
      namaKomoditas: komoditasTerpilih?.namaKomoditas ?? '',
      gradeTerpilih: gradeTerpilih ?? '',
      berat: parseAngka(beratText) ?? 0,
      hargaBeliSatuan: parseAngka(hargaText) ?? 0,
      nominalPotongKasbon: potongan,
      totalBayar: totalBayar,
      fotoFisikBarang: fotoBarang,
      fotoNota: fotoNota,
      // Foto yang ada tetap harus diunggah dulu. Tahap foto yang menetapkan
      // `dilewati` sesudahnya bila salah satunya memang kosong.
      statusFoto: FotoTertunda.adalahPathLokal(fotoNota) || FotoTertunda.adalahPathLokal(fotoBarang)
          ? 'pending'
          : fotoKurang
              ? 'dilewati'
              : 'ok',
      // Masukkan hasil GPS ke model
      latitude: koordinat?.lat ?? _tanpaLokasi,
      longitude: koordinat?.lng ?? _tanpaLokasi,
      statusSinkronisasi: 'pending',
      createdAt: now,
      saranKomoditasAi: grading.saranKomoditasAi,
      komoditasDiubahPengguna: komoditasDiubah(
        grading.saranKomoditasAi,
        komoditasTerpilih?.namaKomoditas ?? '',
      ),
      rubrikVersi: grading.rubrikJawaban == null ? null : rubrikVersi,
      rubrikJawaban: grading.rubrikJawaban == null ? null : List.of(grading.rubrikJawaban!),
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
    return koordinat != null;
  }

  Future<void> updateTransaksi(
    TransaksiHiveModel existingTrx, {
    required PetaniHiveModel? petaniTerpilih,
    required String namaPenjual,
    required KomoditasHiveModel? komoditasTerpilih,
    required String? gradeTerpilih,
    required String beratText,
    required String hargaText,
    required String fotoNotaPath,
    required String fotoBarangPath,
    CatatanGrading? grading,
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

    _periksaBerat(beratText);
    // Hanya bila komoditas, grade, atau harga berubah. Tanpa ini, mengoreksi berat
    // transaksi lama akan ditolak hanya karena batas harganya sudah diturunkan.
    final aturanHargaBerlaku = komoditasTerpilih?.namaKomoditas != existingTrx.namaKomoditas ||
        gradeTerpilih != existingTrx.gradeTerpilih ||
        parseAngka(hargaText) != existingTrx.hargaBeliSatuan;
    if (aturanHargaBerlaku) {
      _periksaHarga(komoditasTerpilih, gradeTerpilih, hargaText);
    }
    final jawabanBaru = grading?.rubrikJawaban;
    _periksaRubrik(komoditasTerpilih, gradeTerpilih, jawabanBaru);
    // Tanpa checklist baru, jawaban lama hanya berlaku bila komoditas dan grade tetap.
    final rubrikLamaBasi = jawabanBaru == null &&
        (komoditasTerpilih?.namaKomoditas != existingTrx.namaKomoditas ||
            gradeTerpilih != existingTrx.gradeTerpilih);

    final totalBayar = getTotalBayar(beratText, hargaText);
    final user = _hive.usersBox.get('currentUser')!;
    final petaniLama = _petaniDari(existingTrx);
    final efek = pratinjauEdit(
      existingTrx,
      petaniTerpilih: petaniTerpilih,
      totalBayar: totalBayar,
    );

    final notaLama = existingTrx.fotoNota;
    final barangLama = existingTrx.fotoFisikBarang;
    final notaBaru = fotoNotaPath.isEmpty || fotoNotaPath == notaLama
        ? notaLama
        : await FotoTertunda.salin(fotoNotaPath, idLokal: existingTrx.idLokal, jenis: 'nota');
    final barangBaru = fotoBarangPath.isEmpty || fotoBarangPath == barangLama
        ? barangLama
        : await FotoTertunda.salin(fotoBarangPath, idLokal: existingTrx.idLokal, jenis: 'barang');

    // Transaksi ditulis dulu. Bila aplikasi mati sebelum saldo tersimpan, sync
    // berikutnya memperbaiki saldo, karena transaksi adalah sumber kebenaran.
    existingTrx.petaniId        = petaniTerpilih?.id ?? '';
    existingTrx.namaPetani      = namaPenjual.trim();
    existingTrx.namaKomoditas   = komoditasTerpilih?.namaKomoditas ?? '';
    existingTrx.gradeTerpilih   = gradeTerpilih ?? '';
    existingTrx.berat           = parseAngka(beratText) ?? 0;
    existingTrx.hargaBeliSatuan = parseAngka(hargaText) ?? 0;
    existingTrx.totalBayar      = totalBayar;
    existingTrx.nominalPotongKasbon = efek.potonganBaru;
    // Saran AI asli dipertahankan; yang berubah hanya apakah pilihan akhir menyimpang.
    existingTrx.komoditasDiubahPengguna =
        komoditasDiubah(existingTrx.saranKomoditasAi, existingTrx.namaKomoditas);
    if (jawabanBaru != null) {
      existingTrx.rubrikVersi = rubrikVersi;
      existingTrx.rubrikJawaban = List.of(jawabanBaru);
    } else if (rubrikLamaBasi) {
      existingTrx.rubrikVersi = null;
      existingTrx.rubrikJawaban = null;
    }

    existingTrx.fotoNota = notaBaru;
    existingTrx.fotoFisikBarang = barangBaru;
    final fotoBaru = (notaBaru != notaLama && FotoTertunda.adalahPathLokal(notaBaru)) ||
        (barangBaru != barangLama && FotoTertunda.adalahPathLokal(barangBaru));
    if (fotoBaru) existingTrx.statusFoto = 'pending';

    // GPS tidak di-update di sini untuk mempertahankan lokasi asli saat transaksi dibuat.
    
    if (existingTrx.statusSinkronisasi == 'synced') {
      existingTrx.statusSinkronisasi = 'pending_update';
    }

    await existingTrx.save();

    if (notaBaru != notaLama) await FotoTertunda.hapusSalinan(notaLama);
    if (barangBaru != barangLama) await FotoTertunda.hapusSalinan(barangLama);

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

  /// Mengembalikan true bila lokasi GPS tercatat, seperti [simpanTransaksi].
  Future<bool> simpanKasbonMurni({
    required PetaniHiveModel petaniTerpilih,
    required String nominalKasbonText,
  }) async {
    final double nominalKasbon = double.tryParse(nominalKasbonText) ?? 0.0;
    if (!nominalKasbon.isFinite || nominalKasbon <= 0) {
      throw const TransaksiDitolak('nominal_tidak_sah', 'Nominal kasbon harus lebih dari nol.');
    }

    final user = _hive.usersBox.get('currentUser')!;
    final now  = DateTime.now();

    // Ambil koordinat GPS murni luring untuk mencatat lokasi pencairan uang
    final koordinat = await _ambilLokasi();

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
      latitude: koordinat?.lat ?? _tanpaLokasi,
      longitude: koordinat?.lng ?? _tanpaLokasi,
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
    return koordinat != null;
  }
}