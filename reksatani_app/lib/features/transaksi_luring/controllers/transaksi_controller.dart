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

  Future<void> simpanTransaksi({
    required PetaniHiveModel? petaniTerpilih,
    required String namaPenjual,
    required KomoditasHiveModel? komoditasTerpilih,
    required String? gradeTerpilih,
    required String beratText,
    required String hargaText,
    required double totalBayar,
  }) async {
    final user = _hive.usersBox.get('currentUser')!;
    final now  = DateTime.now();
    final sisaKasbon  = petaniTerpilih?.sisaHutangKasbon ?? 0;
    final potongan    = sisaKasbon > 0 ? sisaKasbon.clamp(0, totalBayar).toDouble() : 0.0;

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
      fotoFisikBarang: '',
      fotoNota: '',
      latitude: 0,
      longitude: 0,
      statusSinkronisasi: 'pending',
      createdAt: now,
    );

    await _hive.saveTransaksi(trx);

    if (petaniTerpilih != null && potongan > 0) {
      petaniTerpilih.sisaHutangKasbon =
          (petaniTerpilih.sisaHutangKasbon - potongan).clamp(0, double.infinity);
      await petaniTerpilih.save();
    }

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
  }) async {
    existingTrx.petaniId        = petaniTerpilih?.id ?? '';
    existingTrx.namaPetani      = namaPenjual.trim();
    existingTrx.namaKomoditas   = komoditasTerpilih?.namaKomoditas ?? '';
    existingTrx.gradeTerpilih   = gradeTerpilih ?? '';
    existingTrx.berat           = double.tryParse(beratText) ?? 0;
    existingTrx.hargaBeliSatuan = double.tryParse(hargaText) ?? 0;
    existingTrx.totalBayar      = totalBayar;
    
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
