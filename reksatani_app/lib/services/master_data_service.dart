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
    } catch (e) {
      print('Error syncKomoditas: $e');
    }
  }

  Future<void> syncRiwayatTransaksi() async {
    try {
      final user = _hive.usersBox.get('currentUser');
      if (user == null) return;
      
      final col = MongoDatabase.getCollection('transaksi');
      final docs = await col.find({'pengepul_id': user.id}).toList();

      for (final d in docs) {
        final idLokal = d['id_lokal']?.toString() ?? d['_id'].toString();
        if (_hive.transaksiBox.containsKey(idLokal)) continue;

        final m = TransaksiHiveModel(
          idLokal: idLokal,
          pengepulId: d['pengepul_id']?.toString() ?? '',
          petaniId: d['petani_id']?.toString() ?? '',
          namaPengepul: d['nama_pengepul']?.toString() ?? '',
          namaPetani: d['nama_petani']?.toString() ?? '',
          namaKomoditas: d['nama_komoditas']?.toString() ?? '',
          gradeTerpilih: d['grade_terpilih']?.toString() ?? '',
          berat: (d['berat'] ?? 0).toDouble(),
          hargaBeliSatuan: (d['harga_beli_satuan'] ?? 0).toDouble(),
          nominalPotongKasbon: (d['nominal_potong_kasbon'] ?? 0).toDouble(),
          totalBayar: (d['total_bayar'] ?? 0).toDouble(),
          fotoFisikBarang: d['foto_fisik_barang']?.toString() ?? '',
          fotoNota: d['foto_nota']?.toString() ?? '',
          latitude: (d['latitude'] ?? 0).toDouble(),
          longitude: (d['longitude'] ?? 0).toDouble(),
          statusSinkronisasi: d['status_sinkronisasi']?.toString() ?? 'synced',
          createdAt: DateTime.tryParse(d['created_at']?.toString() ?? '') ?? DateTime.now(),
          waktuDisinkron: DateTime.tryParse(d['waktu_disinkron']?.toString() ?? ''),
        );
        await _hive.transaksiBox.put(m.idLokal, m);
      }
    } catch (e) {
      print('Error syncRiwayatTransaksi: $e');
    }
  }

  Future<void> uploadPendingTransaksi() async {
    final pending = _hive.getPendingTransaksi();
    if (pending.isEmpty) return;
    try {
      final col = MongoDatabase.getCollection('transaksi');
      for (final t in pending) {
        final res = await col.insertOne({
          'id_lokal': t.idLokal,
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
        
        if (res.isSuccess) {
          t.statusSinkronisasi = 'synced';
          t.waktuDisinkron = DateTime.now();
          await t.save();
        } else {
          print('Error insertOne dari MongoDB: ${res.errmsg ?? "Unknown Error"}');
        }
      }
    } catch (e) {
      print('Error uploadPendingTransaksi: $e');
    }
  }

  Future<void> syncAll() async {
    await syncPetani();
    await syncKomoditas();
    await uploadPendingTransaksi();
    await syncRiwayatTransaksi();
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