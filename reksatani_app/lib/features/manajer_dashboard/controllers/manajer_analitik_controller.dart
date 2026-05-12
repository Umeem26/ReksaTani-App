import 'package:flutter/material.dart';
import '../../../../models/hive/transaksi_hive_model.dart';
import '../../../../models/hive/user_hive_model.dart';
import '../../../../services/hive_service.dart';
import '../../../../services/master_data_service.dart';

/// Controller untuk ManajerAnalitikScreen.
/// Menyediakan semua kalkulasi analitik yang dibutuhkan dasbor manajer.
class ManajerAnalitikController extends ChangeNotifier {
  final _hive = HiveService();
  final _svc  = MasterDataService();

  bool syncing = false;

  // ── User ─────────────────────────────────────────────────────
  UserHiveModel get user => _hive.usersBox.get('currentUser')!;

  // ── Raw data ─────────────────────────────────────────────────
  List<TransaksiHiveModel> get semuaTransaksi =>
      _svc.getRiwayatTransaksi();

  // ── Ringkasan stok ────────────────────────────────────────────
  double get totalStokKg =>
      semuaTransaksi.fold(0.0, (sum, t) => sum + t.berat);

  double get totalNilai =>
      semuaTransaksi.fold(0.0, (sum, t) => sum + t.totalBayar);

  // ── Status sinkronisasi ───────────────────────────────────────
  int get jumlahPending =>
      semuaTransaksi.where((t) => t.statusSinkronisasi == 'pending').length;

  int get jumlahSynced => semuaTransaksi.length - jumlahPending;

  double get persenSynced => semuaTransaksi.isEmpty
      ? 0
      : jumlahSynced / semuaTransaksi.length;

  // ── Stok per komoditas ────────────────────────────────────────
  /// Returns: [{ 'nama': 'Padi', 'totalKg': 120.0, 'totalNilai': 500000.0 }, ...]
  List<Map<String, dynamic>> get stokPerKomoditas {
    final Map<String, Map<String, dynamic>> map = {};

    // Inisialisasi dengan semua komoditas dari master data
    final daftarKomoditas = _svc.getDaftarKomoditas();
    for (final k in daftarKomoditas) {
      map[k.namaKomoditas] = {
        'nama': k.namaKomoditas,
        'totalKg': 0.0,
        'totalNilai': 0.0
      };
    }

    for (final t in semuaTransaksi) {
      final key = t.namaKomoditas;
      if (!map.containsKey(key)) {
        map[key] = {'nama': key, 'totalKg': 0.0, 'totalNilai': 0.0};
      }
      map[key]!['totalKg'] = (map[key]!['totalKg'] as double) + t.berat;
      map[key]!['totalNilai'] =
          (map[key]!['totalNilai'] as double) + t.totalBayar;
    }
    final list = map.values.toList();
    list.sort((a, b) =>
        (b['totalKg'] as double).compareTo(a['totalKg'] as double));
    return list;
  }

  // ── Stok per grade ────────────────────────────────────────────
  /// Returns: [{ 'grade': 'A', 'totalKg': 80.0 }, ...]
  List<Map<String, dynamic>> get stokPerGrade {
    final Map<String, double> map = {};

    // Ambil semua grade unik dari master data komoditas
    final daftarKomoditas = _svc.getDaftarKomoditas();
    for (final k in daftarKomoditas) {
      for (final g in k.gradeKualitas) {
        final namaGrade = g['grade']?.toString() ?? '';
        if (namaGrade.isNotEmpty && !map.containsKey(namaGrade)) {
          map[namaGrade] = 0.0;
        }
      }
    }

    // Tambahkan berat dari transaksi yang ada
    for (final t in semuaTransaksi) {
      final g = t.gradeTerpilih;
      if (g.isNotEmpty) {
        map[g] = (map[g] ?? 0.0) + t.berat;
      }
    }

    final list = map.entries
        .map((e) => {'grade': e.key, 'totalKg': e.value})
        .toList();

    // Urutkan berdasarkan grade (A, B, C...)
    list.sort((a, b) => (a['grade'] as String).compareTo(b['grade'] as String));
    return list;
  }

  // ── Distribusi transaksi per komoditas ─────────────────────────
  /// Returns: [{ 'nama': 'Padi', 'jumlahTransaksi': 8 }, ...] sorted desc
  List<Map<String, dynamic>> get distribusiTransaksi {
    final Map<String, int> map = {};

    // Inisialisasi dengan semua komoditas dari master data
    final daftarKomoditas = _svc.getDaftarKomoditas();
    for (final k in daftarKomoditas) {
      map[k.namaKomoditas] = 0;
    }

    for (final t in semuaTransaksi) {
      map[t.namaKomoditas] = (map[t.namaKomoditas] ?? 0) + 1;
    }
    final list = map.entries
        .map((e) => {'nama': e.key, 'jumlahTransaksi': e.value})
        .toList();
    list.sort((a, b) =>
        (b['jumlahTransaksi'] as int).compareTo(a['jumlahTransaksi'] as int));
    return list;
  }

  // ── Refresh / sync ────────────────────────────────────────────
  Future<void> refresh() async {
    syncing = true;
    notifyListeners();
    await _svc.syncAll();
    syncing = false;
    notifyListeners();
  }
}