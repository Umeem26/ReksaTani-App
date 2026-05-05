import '../services/hive_service.dart';
import '../services/mongodb_service.dart';
import '../models/hive/petani_hive_model.dart';
import '../models/hive/komoditas_hive_model.dart';
import '../models/hive/transaksi_hive_model.dart';

/// SRP: Satu-satunya class yang boleh baca/tulis data master
/// antara MongoDB dan Hive lokal.
class MasterDataService {
  static final MasterDataService _i = MasterDataService._();
  factory MasterDataService() => _i;
  MasterDataService._();

  final _hive = HiveService();

  // ── SYNC MongoDB → Hive ────────────────────────────────────────
  Future<void> syncPetani() async {
    try {
      final docs =
          await MongoDatabase.getCollection('petani').find().toList();
      await _hive.petaniBox.clear();
      for (final d in docs) {
        final m = PetaniHiveModel(
          id: d['_id'].toString(),
          namaPetani: d['nama_petani'] ?? '',
          desa: d['desa'] ?? '',
          pengepulId: d['pengepul_id']?.toString() ?? '',
          sisaHutangKasbon: (d['sisa_hutang_kasbon'] ?? 0).toDouble(),
          waktuDibuat: DateTime.tryParse(d['waktu_dibuat']?.toString() ?? '') ??
              DateTime.now(),
        );
        await _hive.petaniBox.put(m.id, m);
      }
    } catch (_) {}
  }

  Future<void> syncKomoditas() async {
    try {
      final docs =
          await MongoDatabase.getCollection('komoditas').find().toList();
      await _hive.komoditasBox.clear();
      for (final d in docs) {
        // gradeKualitas di MongoDB: [{grade: 'A', harga_maks: 6500}, ...]
        final grades = (d['grade_kualitas'] as List<dynamic>? ?? [])
            .map<Map<String, dynamic>>((g) => {
                  'grade': g['grade'] ?? '',
                  'harga_maks': (g['harga_maks'] ?? 0).toDouble(),
                })
            .toList();

        final m = KomoditasHiveModel(
          id: d['_id'].toString(),
          namaKomoditas: d['nama_komoditas'] ?? '',
          unitSatuan: d['unit_satuan'] ?? 'kg',
          gradeKualitas: grades,
          diperbaruiOleh: d['diperbarui_oleh']?.toString() ?? '',
          waktuPembaruan:
              DateTime.tryParse(d['waktu_pembaruan']?.toString() ?? '') ??
                  DateTime.now(),
        );
        await _hive.komoditasBox.put(m.id, m);
      }
    } catch (_) {}
  }

  Future<void> uploadPendingTransaksi() async {
    final pending = _hive.getPendingTransaksi();
    if (pending.isEmpty) return;
    try {
      final col = MongoDatabase.getCollection('transaksi');
      for (final t in pending) {
        await col.insertOne({
          'pengepul_id': t.pengepulId,
          'petani_id': t.petaniId,
          'nama_pengepul': t.namaPengepul,
          'nama_petani': t.namaPetani,
          'nama_komoditas': t.namaKomoditas,
          'grade_terpilih': t.gradeTerpilih,
          'berat': t.berat,
          'harga_beli_satuan': t.hargaBeliSatuan,
          'nominal_potong_kasbon': t.nominalPotongKasbon,
          'total_bayar': t.totalBayar,
          'foto_fisik_barang': t.fotoFisikBarang,
          'foto_nota': t.fotoNota,
          'latitude': t.latitude,
          'longitude': t.longitude,
          'status_sinkronisasi': 'synced',
          'created_at': t.createdAt.toIso8601String(),
        });
        t.statusSinkronisasi = 'synced';
        t.waktuDisinkron = DateTime.now();
        await t.save();
      }
    } catch (_) {}
  }

  Future<void> syncAll() async {
    await syncPetani();
    await syncKomoditas();
    await uploadPendingTransaksi();
  }

  // ── GETTER untuk UI (dari Hive lokal) ──────────────────────────
  List<PetaniHiveModel> getDaftarPetani() =>
      _hive.petaniBox.values.toList();

  List<KomoditasHiveModel> getDaftarKomoditas() =>
      _hive.komoditasBox.values.toList();

  /// Flatten komoditas + grade → list siap tampil
  /// Output: [{namaKomoditas, grade, hargaMaks, unitSatuan, komoditasId}]
  List<Map<String, dynamic>> getDaftarHargaDisplay() =>
      _hive.komoditasBox.values.expand((k) {
        return k.gradeKualitas.map((g) => {
              'namaKomoditas': k.namaKomoditas,
              'unitSatuan': k.unitSatuan,
              'grade': g['grade'] as String,
              'hargaMaks': (g['harga_maks'] as num).toDouble(),
              'komoditasId': k.id,
            });
      }).toList();

  List<TransaksiHiveModel> getRiwayatTransaksi() =>
      _hive.transaksiBox.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  int get jumlahPending => _hive.getPendingTransaksi().length;

  double get totalBeratHariIni {
    final today = DateTime.now();
    return _hive.transaksiBox.values
        .where((t) =>
            t.createdAt.year == today.year &&
            t.createdAt.month == today.month &&
            t.createdAt.day == today.day)
        .fold(0.0, (s, t) => s + t.berat);
  }
}