import 'dart:developer' as developer;

import 'package:flutter/foundation.dart'; // Wajib untuk ChangeNotifier
import '../services/hive_service.dart';
import '../services/cloudinary_service.dart';
import '../models/hive/petani_hive_model.dart';
import '../models/hive/komoditas_hive_model.dart';
import '../models/hive/transaksi_hive_model.dart';
import '../models/hive/user_hive_model.dart';
import 'notification_service.dart';
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

  DateTime parseDateTime(dynamic val) => parseDateTimeNullable(val) ?? DateTime.now();

  DateTime? parseDateTimeNullable(dynamic val) => SyncEngine.tanggal(val);

  // ─── JANTUNG AUTO-SYNC ───
  Future<void> syncAll() async {
    if (isSyncing) return; // Cegah double trigger
    isSyncing = true;
    notifyListeners(); // Beritahu UI kalau loading spinner bisa dimunculkan

    final masalah = <SyncIssue>[];
    var terkirim = 0;

    try {
      final isDbReady = await _engineAktif.remote.ping();
      if (!isDbReady) {
        // Tidak ada internet: batalkan proses sync secara halus
        masalah.add(const SyncIssue(
          tahap: 'ping',
          jenis: 'offline',
          pesan: 'Database tidak terjangkau',
        ));
        return;
      }

      final pendingCount = _hive.getPendingTransaksi().length;

      final laporan = await _engineAktif.siklus();
      terkirim = laporan.terkirim;
      masalah.addAll(laporan.masalah);

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

      if (isManajer && laporan.riwayatBaru > 0) {
        NotificationService().addNotification(
          judul: 'Transaksi Baru',
          pesan: 'Ada ${laporan.riwayatBaru} transaksi baru masuk dari agen lapangan.',
          tipe: 'info',
        );
      }

    } catch (e) {
      developer.log('Siklus sync gagal: ${e.runtimeType}', name: 'MasterDataService');
      masalah.add(SyncIssue(
        tahap: 'siklus',
        jenis: 'siklus_gagal',
        pesan: e.runtimeType.toString(),
      ));
    } finally {
      laporanTerakhir = SyncReport(
        masalah: masalah,
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
            t.createdAt.day == today.day &&
            t.statusSinkronisasi != 'pending_delete')
        .fold(0.0, (s, t) => s + t.berat);
  }
}
