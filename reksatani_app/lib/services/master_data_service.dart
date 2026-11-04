import 'dart:developer' as developer;

import 'package:flutter/foundation.dart'; // Wajib untuk ChangeNotifier
import 'package:mongo_dart/mongo_dart.dart' show modify, where;
import '../services/hive_service.dart';
import '../services/mongodb_service.dart';
import '../services/cloudinary_service.dart';
import '../models/hive/petani_hive_model.dart';
import '../models/hive/komoditas_hive_model.dart';
import '../models/hive/transaksi_hive_model.dart';
import '../models/hive/user_hive_model.dart';
import 'notification_service.dart';
import 'sync/mongo_id.dart';
import 'sync/mongo_remote.dart';
import 'sync/sync_engine.dart';
import 'sync/sync_report.dart';

/// SRP: Satu-satunya class yang boleh baca/tulis data master
/// antara MongoDB dan Hive lokal. Sekarang bersifat REACTIVE (ChangeNotifier).
class MasterDataService extends ChangeNotifier { // <--- 2. Tambahkan extends ChangeNotifier
  static final MasterDataService _i = MasterDataService._();
  factory MasterDataService() => _i;
  MasterDataService._();

  final _hive = HiveService();
  final _cloudinary = CloudinaryService();

  SyncEngine? _engine;
  SyncEngine get _engineAktif => _engine ??= SyncEngine(
        remote: MongoRemote(),
        hive: _hive,
        unggahFoto: _cloudinary.uploadImage,
      );

  /// Menyuntikkan engine dengan remote palsu, supaya tes tidak menyentuh jaringan.
  @visibleForTesting
  set engine(SyncEngine engine) => _engine = engine;

  // Flag penanda agar tidak terjadi tumpang tindih saat sync
  bool isSyncing = false;

  /// Hasil siklus sinkronisasi terakhir.
  SyncReport? laporanTerakhir;
  final List<SyncIssue> _masalahSiklus = [];

  // ── SYNC MongoDB → Hive ────────────────────────────────────────
  Future<void> syncPetani() async {
    try {
      final docs = await MongoDatabase.getCollection('petani').find().toList();
      await _hive.petaniBox.clear();
      for (final d in docs) {
        final m = PetaniHiveModel(
          id: MongoId.kanonik(d['_id']),
          namaPetani: d['nama_petani'] ?? '',
          desa: d['desa'] ?? '',
          pengepulId: MongoId.kanonik(d['pengepul_id']),
          sisaHutangKasbon: (d['sisa_hutang_kasbon'] ?? 0).toDouble(),
          waktuDibuat: DateTime.tryParse(d['waktu_dibuat']?.toString() ?? '') ?? DateTime.now(),
        );
        await _hive.petaniBox.put(m.id, m);
      }
    } catch (_) {}
  }

  Future<void> syncKomoditas() async {
    try {
      final docs = await MongoDatabase.getCollection('komoditas').find().toList();
      await _hive.komoditasBox.clear();
      for (final d in docs) {
        final grades = (d['grade_kualitas'] as List<dynamic>? ?? [])
            .map<Map<String, dynamic>>((g) => {
                  'grade': g['grade'] ?? '',
                  'harga_maks': (g['harga_maks'] ?? 0).toDouble(),
                })
            .toList();

        final m = KomoditasHiveModel(
          id: MongoId.kanonik(d['_id']),
          namaKomoditas: d['nama_komoditas'] ?? '',
          unitSatuan: d['unit_satuan'] ?? 'kg',
          gradeKualitas: grades,
          diperbaruiOleh: d['diperbarui_oleh']?.toString() ?? '',
          waktuPembaruan: DateTime.tryParse(d['waktu_pembaruan_harga']?.toString() ?? '') ?? DateTime.now(),
        );
        await _hive.komoditasBox.put(m.id, m);
      }
    } catch (e) {
      print('Error syncKomoditas: $e');
    }
  }

  Future<void> syncAgents() async {
    try {
      final col = MongoDatabase.getCollection('users');
      final docs = await col.find({'role': 'pengepul'}).toList();

      final keysToDelete = _hive.usersBox.keys.where((k) => k != 'currentUser').toList();
      await _hive.usersBox.deleteAll(keysToDelete);

      for (final d in docs) {
        final m = UserHiveModel(
          id: MongoId.kanonik(d['_id']),
          username: d['username'] ?? '',
          passwordHash: '', 
          role: d['role'] ?? 'pengepul',
          sisaUangJalan: (d['sisa_uang_jalan'] ?? 0).toDouble(),
          waktuDibuat: DateTime.tryParse(d['waktu_dibuat']?.toString() ?? '') ?? DateTime.now(),
        );
        await _hive.usersBox.put(m.id, m);
      }
    } catch (e) {
      print('Error syncAgents: $e');
    }
  }

  Future<int> syncRiwayatTransaksi() async {
    int countBaru = 0;
    try {
      final user = _hive.usersBox.get('currentUser');
      if (user == null) return 0;

      final col = MongoDatabase.getCollection('transaksi');
      
      final dynamic selector = (user.role == 'manager' || user.role == 'manajer' || user.role == 'admin')
          ? where.ne('pengepul_id', '')
          : MongoId.filterRef('pengepul_id', user.id);

      final docs = await col.find(selector).toList();

      for (final d in docs) {
        // Sengaja bukan MongoId.kanonik untuk `_id`: baris lama dari dokumen tanpa
        // id_lokal sudah tersimpan dengan kunci ini, dan idLokal adalah kunci opak.
        final idLokal = d['id_lokal']?.toString() ?? d['_id'].toString();
        if (_hive.transaksiBox.containsKey(idLokal)) continue;

        final m = TransaksiHiveModel(
          idLokal: idLokal,
          pengepulId: MongoId.kanonik(d['pengepul_id']),
          petaniId: MongoId.kanonik(d['petani_id']),
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
          createdAt: parseDateTime(d['created_at']),
          waktuDisinkron: parseDateTimeNullable(d['waktu_disinkron']),
        );
        await _hive.transaksiBox.put(m.idLokal, m);
        countBaru++;
      }
    } catch (e) {
      print('Error syncRiwayatTransaksi: $e');
    }
    return countBaru;
  }

  DateTime parseDateTime(dynamic val) {
    if (val == null) return DateTime.now();
    if (val is DateTime) return val;
    return DateTime.tryParse(val.toString()) ?? DateTime.now();
  }

  DateTime? parseDateTimeNullable(dynamic val) {
    if (val == null) return null;
    if (val is DateTime) return val;
    return DateTime.tryParse(val.toString());
  }

  /// Server menjawab sukses walau filter tidak mengenai dokumen apa pun, jadi
  /// jumlah dokumen yang kena harus diperiksa.
  Future<void> _incSaldo(String koleksi, String id, String field, double delta) async {
    final hasil = await MongoDatabase.getCollection(koleksi).updateOne(
      MongoId.filterId(id),
      modify.inc(field, delta),
    );
    if (hasil.nMatched == 0) {
      developer.log('Saldo tidak terbarui: $koleksi/$id tidak ditemukan', name: 'MasterDataService');
      _masalahSiklus.add(SyncIssue(
        tahap: 'push_hapus',
        jenis: 'saldo_tidak_terbarui',
        pesan: '$koleksi/$id',
      ));
    }
  }

  Future<void> uploadPendingDeleteTransaksi() async {
    try {
      final deletes = _hive.getPendingDeleteTransaksi();
      if (deletes.isEmpty) return;

      final coll = MongoDatabase.getCollection('transaksi');
      for (final t in deletes) {
        final res = await coll.deleteOne(where.eq('id_lokal', t.idLokal));

        if (res.isSuccess) {
          if (t.nominalPotongKasbon > 0 && t.petaniId.isNotEmpty) {
            try {
              await _incSaldo('petani', t.petaniId, 'sisa_hutang_kasbon', t.nominalPotongKasbon);
            } catch (e) {}
          }

          final uangTunaiKeluar = t.totalBayar - t.nominalPotongKasbon;
          if (uangTunaiKeluar > 0) {
            try {
              await _incSaldo('users', t.pengepulId, 'sisa_uang_jalan', uangTunaiKeluar);
            } catch (e) {}
          }

          await _hive.transaksiBox.delete(t.idLokal);
        }
      }
    } catch (e) {
      print('Error uploadPendingDeleteTransaksi: $e');
    }
  }

  // ─── JANTUNG AUTO-SYNC (DIPERBARUI) ───
  Future<void> syncAll() async {
    if (isSyncing) return; // Cegah double trigger
    isSyncing = true;
    notifyListeners(); // Beritahu UI kalau loading spinner bisa dimunculkan

    _masalahSiklus.clear();
    var terkirim = 0;

    try {
      // PERBAIKAN ERROR 2: Gunakan fungsi ping() bawaanmu yang sudah dilengkapi auto-reconnect!
      final isDbReady = await _engineAktif.remote.ping();
      if (!isDbReady) {
         // Jika ping gagal (tidak ada internet), batalkan proses sync secara halus
         _masalahSiklus.add(const SyncIssue(
           tahap: 'ping',
           jenis: 'offline',
           pesan: 'Database tidak terjangkau',
         ));
         return;
      }

      final pendingCount = _hive.getPendingTransaksi().length;

      await syncPetani();
      await syncKomoditas();
      await syncAgents();
      final laporanPush = await _engineAktif.pushTransaksi();
      terkirim = laporanPush.terkirim;
      _masalahSiklus.addAll(laporanPush.masalah);
      await uploadPendingDeleteTransaksi();
      final trxBaru = await syncRiwayatTransaksi();

      final remainingCount = _hive.getPendingTransaksi().length;
      final successCount = pendingCount - remainingCount;
      
      final user = _hive.usersBox.get('currentUser');
      final isPengepul = user?.role == 'pengepul';
      final isManajer = user?.role == 'manager' || user?.role == 'manajer' || user?.role == 'admin';

      if (isPengepul) {
        if (successCount > 0) {
          NotificationService().addNotification(
            judul: 'Sinkronisasi Otomatis Berhasil',
            pesan: '$successCount transaksi telah berhasil diunggah ke server.',
            tipe: 'sync',
          );
        }
      }

      if (isManajer && trxBaru > 0) {
        NotificationService().addNotification(
          judul: 'Transaksi Baru',
          pesan: 'Ada $trxBaru transaksi baru masuk dari agen lapangan.',
          tipe: 'info',
        );
      }

    } catch (e) {
      print('Auto-Sync failed: $e');
      _masalahSiklus.add(SyncIssue(
        tahap: 'siklus',
        jenis: 'siklus_gagal',
        pesan: e.runtimeType.toString(),
      ));
    } finally {
      laporanTerakhir = SyncReport(
        masalah: _masalahSiklus,
        terkirim: terkirim,
        selesai: DateTime.now(),
      );
      isSyncing = false;
      notifyListeners(); // 🔴 PENTING: BERITAHU SELURUH UI UNTUK RENDER ULANG!
    }
  }

  // ── GETTER untuk UI (dari Hive lokal) ──────────────────────────
  void _seedDefaultKomoditasIfMissing() {
    final Map<String, List<Map<String, dynamic>>> defaultGrades = {
      'Gabah': [
        {'grade': 'A', 'harga_maks': 7500.0},
        {'grade': 'B', 'harga_maks': 6800.0},
        {'grade': 'C', 'harga_maks': 6000.0},
      ],
      'Kopi Robusta': [
        {'grade': 'A', 'harga_maks': 42000.0},
        {'grade': 'B', 'harga_maks': 38000.0},
        {'grade': 'C', 'harga_maks': 34000.0},
      ],
      'Sawit': [
        {'grade': 'A', 'harga_maks': 2800.0},
        {'grade': 'B', 'harga_maks': 2400.0},
        {'grade': 'C', 'harga_maks': 2000.0},
      ],
    };

    for (final name in defaultGrades.keys) {
      bool exists = _hive.komoditasBox.values.any((k) => k.namaKomoditas.toLowerCase() == name.toLowerCase());
      if (!exists) {
        final id = name.toLowerCase().replaceAll(' ', '_');
        final m = KomoditasHiveModel(
          id: id,
          namaKomoditas: name,
          unitSatuan: 'kg',
          gradeKualitas: defaultGrades[name]!,
          diperbaruiOleh: 'sistem',
          waktuPembaruan: DateTime.now(),
        );
        _hive.komoditasBox.put(m.id, m);
      }
    }
  }

  List<KomoditasHiveModel> getDaftarKomoditas() {
    final allowedNames = {'gabah', 'kopi robusta', 'sawit'};
    _seedDefaultKomoditasIfMissing();
    return _hive.komoditasBox.values
        .where((k) => allowedNames.contains(k.namaKomoditas.toLowerCase()))
        .toList();
  }

  List<PetaniHiveModel> getDaftarPetani() => _hive.petaniBox.values.toList();
  
  List<UserHiveModel> getDaftarAgen() => _hive.usersBox.values.where((u) => u.role == 'pengepul').toList();

  List<Map<String, dynamic>> getDaftarHargaDisplay() {
    final allowedNames = {'gabah', 'kopi robusta', 'sawit'};
    _seedDefaultKomoditasIfMissing();
    return _hive.komoditasBox.values
        .where((k) => allowedNames.contains(k.namaKomoditas.toLowerCase()))
        .expand((k) {
          return k.gradeKualitas.map((g) => {
                'namaKomoditas': k.namaKomoditas,
                'unitSatuan': k.unitSatuan,
                'grade': g['grade'] as String,
                'hargaMaks': (g['harga_maks'] as num).toDouble(),
                'komoditasId': k.id,
              });
        }).toList();
  }

  List<TransaksiHiveModel> getRiwayatTransaksi() =>
      _hive.transaksiBox.values
        .where((t) => t.statusSinkronisasi != 'pending_delete')
        .toList()
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