import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:flutter/foundation.dart'; // Wajib untuk ChangeNotifier
import '../services/hive_service.dart';
import '../services/cloudinary_service.dart';
import '../models/hive/petani_hive_model.dart';
import '../models/hive/komoditas_hive_model.dart';
import '../models/hive/transaksi_hive_model.dart';
import '../models/hive/user_hive_model.dart';
import 'notification_service.dart';
import 'sync/mongo_remote.dart';
import 'sync/retry_policy.dart';
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
  /// Timer retry dimatikan juga, karena ia akan memicu sync di tengah tes lain.
  @visibleForTesting
  set engine(SyncEngine engine) {
    _engine = engine;
    _timerRetry?.cancel();
    _timerRetry = null;
    penjadwalRetry = (_, _) => null;
    gagalBeruntun = 0;
    _percobaanRetry = 0;
    _ulangSetelahSelesai = false;
    _berjalan = null;
  }

  // Flag penanda agar tidak terjadi tumpang tindih saat sync
  bool isSyncing = false;

  /// Hasil siklus sinkronisasi terakhir.
  SyncReport? laporanTerakhir;

  /// Siklus gagal berturut-turut sampai saat ini.
  int gagalBeruntun = 0;

  /// Batas seluruh siklus, supaya `isSyncing` selalu kembali false.
  @visibleForTesting
  Duration batasSiklus = const Duration(minutes: 5);

  @visibleForTesting
  Timer? Function(Duration tunda, void Function() aksi) penjadwalRetry = Timer.new;

  @visibleForTesting
  double Function() acakRetry = Random().nextDouble;

  @visibleForTesting
  DateTime Function() jam = DateTime.now;

  static const String _kunciBerhasil = 'syncTerakhirBerhasil';
  static const String _kunciGagal = 'syncTerakhirGagal';
  static const String _kunciJenisGagal = 'syncJenisGagal';
  static const String _jenisOffline = 'offline';

  /// Pill baru muncul setelah gagal dua kali, supaya tidak berkedip.
  static const int _ambangPeringatan = 2;

  final _retry = const RetryPolicy();
  Timer? _timerRetry;
  int _percobaanRetry = 0;
  bool _ulangSetelahSelesai = false;
  Future<void>? _berjalan;

  DateTime parseDateTime(dynamic val) => parseDateTimeNullable(val) ?? DateTime.now();

  DateTime? parseDateTimeNullable(dynamic val) => SyncEngine.tanggal(val);

  // ─── JANTUNG AUTO-SYNC ───

  /// Menunggu sampai data benar-benar tersinkron, termasuk bila ada sync yang
  /// sedang berjalan: pemicu saat itu menjadwalkan satu siklus lagi, karena data
  /// yang memicunya bisa saja belum terbaca oleh siklus yang berjalan.
  Future<void> syncAll() => _picu(dariRetry: false);

  Future<void> _picu({required bool dariRetry}) {
    if (!dariRetry && _percobaanRetry >= RetryPolicy.batas) _percobaanRetry = 0;

    if (isSyncing) {
      _ulangSetelahSelesai = true;
      return _berjalan ?? Future<void>.value();
    }

    isSyncing = true;
    _timerRetry?.cancel();
    _timerRetry = null;
    notifyListeners(); // Beritahu UI kalau loading spinner bisa dimunculkan
    return _berjalan = _jalankan();
  }

  Future<void> _jalankan() async {
    try {
      do {
        _ulangSetelahSelesai = false;
        await _satuSiklus();
      } while (_ulangSetelahSelesai);
      _jadwalkanRetry();
    } finally {
      _berjalan = null;
      isSyncing = false;
      notifyListeners(); // 🔴 PENTING: BERITAHU SELURUH UI UNTUK RENDER ULANG!
    }
  }

  Future<void> _satuSiklus() async {
    final engine = _engineAktif;
    SyncReport laporan;
    try {
      laporan = await _pingLaluSiklus(engine).timeout(batasSiklus, onTimeout: () {
        engine.batalkanSiklus();
        return SyncReport(
          masalah: const [
            SyncIssue(
              tahap: 'siklus',
              jenis: 'siklus_timeout',
              pesan: 'Siklus melewati batas waktu',
            ),
          ],
          terkirim: 0,
          selesai: jam(),
        );
      });
    } catch (e) {
      developer.log('Siklus sync gagal: ${e.runtimeType}', name: 'MasterDataService');
      laporan = SyncReport(
        masalah: [
          SyncIssue(
            tahap: 'siklus',
            jenis: 'siklus_gagal',
            pesan: e.runtimeType.toString(),
          ),
        ],
        terkirim: 0,
        selesai: jam(),
      );
    }
    laporanTerakhir = laporan;
    await _catatHasil(laporan);
  }

  Future<SyncReport> _pingLaluSiklus(SyncEngine engine) async {
    final isDbReady = await engine.remote.ping();
    if (!isDbReady) {
      // Tidak ada internet: batalkan proses sync secara halus
      return SyncReport(
        masalah: const [
          SyncIssue(
            tahap: 'ping',
            jenis: _jenisOffline,
            pesan: 'Database tidak terjangkau',
          ),
        ],
        terkirim: 0,
        selesai: jam(),
      );
    }

    final pendingCount = _hive.getPendingTransaksi().length;

    final laporan = await engine.siklus();

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

    return laporan;
  }

  /// Menyimpan status sebagai nilai primitif, supaya tetap terbaca sesudah aplikasi
  /// dimulai ulang tanpa adapter baru. Kegagalan di sini tidak boleh menghentikan
  /// sync.
  Future<void> _catatHasil(SyncReport laporan) async {
    final gagal = laporan.kegagalanPertama;
    gagalBeruntun = gagal == null ? 0 : gagalBeruntun + 1;

    try {
      final settings = _hive.settingsBox;
      if (gagal == null) {
        await settings.put(_kunciBerhasil, laporan.selesai.toIso8601String());
        await settings.delete(_kunciJenisGagal);
        return;
      }

      // Offline adalah keadaan biasa di lapangan, dan pill sudah menampilkannya.
      final sudahDiberitahu =
          settings.get(_kunciJenisGagal) != null && settings.get(_kunciJenisGagal) != _jenisOffline;

      await settings.put(_kunciGagal, laporan.selesai.toIso8601String());
      await settings.put(_kunciJenisGagal, gagal.jenis);

      if (gagal.jenis != _jenisOffline && !sudahDiberitahu) {
        final menunggu = jumlahMenunggu;
        await NotificationService().addNotification(
          judul: 'Sinkronisasi Gagal',
          pesan: menunggu > 0
              ? '$menunggu data belum terkirim ke server. Aplikasi akan mencoba lagi otomatis.'
              : 'Data belum diperbarui dari server. Aplikasi akan mencoba lagi otomatis.',
          tipe: 'sync',
        );
      }
    } catch (e) {
      developer.log('Status sync tidak tersimpan: ${e.runtimeType}', name: 'MasterDataService');
    }
  }

  void _jadwalkanRetry() {
    final perlu = (laporanTerakhir?.gagalSinkron ?? false) || jumlahMenunggu > 0;
    if (!perlu) {
      _percobaanRetry = 0;
      return;
    }
    _percobaanRetry++;
    final tunda = _retry.tunda(_percobaanRetry, acak: acakRetry());
    if (tunda == null) return; // Berhenti sampai ada pemicu baru.
    _timerRetry = penjadwalRetry(tunda, () => _picu(dariRetry: true));
  }

  /// Baris yang masih harus dikirim dari perangkat ini, termasuk foto.
  int get jumlahMenunggu {
    try {
      return _hive.transaksiBox.values
              .where((t) => t.statusSinkronisasi != 'synced' || t.statusFoto == 'pending')
              .length +
          _hive.petaniBox.values.where((p) => p.statusSinkronisasi != 'synced').length;
    } catch (_) {
      return 0; // Box sudah ditutup.
    }
  }

  /// True bila pill "Gagal sinkron" perlu tampil.
  bool get perluPeringatanSinkron => gagalBeruntun >= _ambangPeringatan;

  String get pesanGagalSinkron => 'Gagal sinkron · $jumlahMenunggu data menunggu';

  /// Satu baris status untuk layar profil.
  ///
  /// Offline tidak disebut gagal, karena status koneksi sudah tampil di sebelahnya.
  String get ringkasanSinkron {
    final settings = _hive.settingsBox;
    final jenisGagal = settings.get(_kunciJenisGagal);
    final menunggu = jumlahMenunggu;
    final akhiran = menunggu > 0 ? ' · $menunggu data menunggu' : '';

    if (jenisGagal != null && jenisGagal != _jenisOffline) {
      return 'Gagal sinkron$akhiran';
    }
    final berhasil = SyncEngine.tanggal(settings.get(_kunciBerhasil));
    if (berhasil == null) return 'Belum pernah sinkron$akhiran';
    return 'Terakhir sinkron: ${_waktu(berhasil.toLocal())}$akhiran';
  }

  String _waktu(DateTime t) {
    String dua(int n) => n.toString().padLeft(2, '0');
    final sekarang = jam();
    final jamMenit = '${dua(t.hour)}.${dua(t.minute)}';
    final hariIni =
        t.year == sekarang.year && t.month == sekarang.month && t.day == sekarang.day;
    return hariIni ? jamMenit : '${dua(t.day)}/${dua(t.month)} $jamMenit';
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

  List<PetaniHiveModel> getDaftarPetani() => _hive.petaniAktif.toList();

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
