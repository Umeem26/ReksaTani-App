import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/hive/user_hive_model.dart';
import '../models/hive/petani_hive_model.dart';
import '../models/hive/komoditas_hive_model.dart';
import '../models/hive/transaksi_hive_model.dart';
import 'notification_service.dart';
import '../models/hive/notifikasi_hive_model.dart';
import 'sync/mongo_id.dart';

class HiveService {
  static final HiveService _instance = HiveService._internal();
  factory HiveService() => _instance;
  HiveService._internal();

  static const String _usersBoxName = 'usersBox';
  static const String _petaniBoxName = 'petaniBox';
  static const String _komoditasBoxName = 'komoditasBox';
  static const String _transaksiBoxName = 'transaksiBox';
  static const String _settingsBoxName = 'settingsBox';

  static const String _folderKarantina = 'hive_karantina';
  static const int _batasSalinanKarantina = 3;

  static const String _kunciVersiId = 'idSchemaVersion';
  static const int _versiIdKanonik = 2;

  String? _testPath;
  final List<String> _dikarantina = [];

  /// Sumber waktu untuk nama salinan karantina.
  @visibleForTesting
  DateTime Function() jam = DateTime.now;

  Future<void> init({String? testPath}) async {
    _testPath = testPath;
    _dikarantina.clear();

    if (testPath != null) {
      Hive.init(testPath);
    } else {
      await Hive.initFlutter();
    }

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(UserHiveModelAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(PetaniHiveModelAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(KomoditasHiveModelAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(TransaksiHiveModelAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(NotifikasiHiveModelAdapter());
    }

    await _openBoxSafe<UserHiveModel>(_usersBoxName);
    await _openBoxSafe<PetaniHiveModel>(_petaniBoxName);
    await _openBoxSafe<KomoditasHiveModel>(_komoditasBoxName);
    await _openBoxSafe<TransaksiHiveModel>(_transaksiBoxName);
    await _openBoxSafe<NotifikasiHiveModel>('notifikasiBox');
    await _openBoxSafe(_settingsBoxName);

    await _beritahuKarantina();
    await _migrasiIdKanonik();
  }

  /// Sekali jalan: mengubah literal `ObjectId("<hex>")` di Hive ke bentuk kanonik.
  ///
  /// Setiap langkah aman dijalankan ulang, dan versi baru ditulis paling akhir,
  /// sehingga aplikasi yang mati di tengah akan melanjutkannya pada start berikut.
  /// `idLokal` sengaja tidak disentuh: nilainya kunci opak yang sudah ada di cloud.
  Future<void> _migrasiIdKanonik() async {
    if (settingsBox.get(_kunciVersiId) == _versiIdKanonik) return;
    try {
      await _migrasiPetani();
      await _migrasiUsers();
      await _migrasiTransaksi();
      await settingsBox.put(_kunciVersiId, _versiIdKanonik);
    } catch (e) {
      // Jangan menghalangi aplikasi terbuka. Dicoba lagi pada start berikutnya.
      debugPrint('[HiveService] Migrasi id tertunda: ${e.runtimeType}');
    }
  }

  Future<void> _migrasiPetani() async {
    for (final kunciLama in petaniBox.keys.toList()) {
      final lama = petaniBox.get(kunciLama);
      if (lama == null) continue;
      final id = MongoId.kanonik(lama.id);
      final pengepulId = MongoId.kanonik(lama.pengepulId);

      if (kunciLama == id) {
        if (lama.id != id || lama.pengepulId != pengepulId) {
          lama
            ..id = id
            ..pengepulId = pengepulId;
          await lama.save();
        }
        continue;
      }

      // Objek Hive tidak bisa disimpan di dua kunci, jadi perlu objek baru.
      // Kunci lama baru dihapus setelah kunci baru tertulis.
      if (!petaniBox.containsKey(id)) {
        await petaniBox.put(
          id,
          PetaniHiveModel(
            id: id,
            namaPetani: lama.namaPetani,
            desa: lama.desa,
            pengepulId: pengepulId,
            sisaHutangKasbon: lama.sisaHutangKasbon,
            waktuDibuat: lama.waktuDibuat,
          ),
        );
      }
      await petaniBox.delete(kunciLama);
    }
  }

  Future<void> _migrasiUsers() async {
    for (final kunciLama in usersBox.keys.toList()) {
      final lama = usersBox.get(kunciLama);
      if (lama == null) continue;
      final id = MongoId.kanonik(lama.id);

      if (kunciLama == 'currentUser' || kunciLama == id) {
        if (lama.id != id) {
          lama.id = id;
          await lama.save();
        }
        continue;
      }

      if (!usersBox.containsKey(id)) {
        await usersBox.put(
          id,
          UserHiveModel(
            id: id,
            username: lama.username,
            passwordHash: lama.passwordHash,
            role: lama.role,
            sisaUangJalan: lama.sisaUangJalan,
            waktuDibuat: lama.waktuDibuat,
          ),
        );
      }
      await usersBox.delete(kunciLama);
    }
  }

  Future<void> _migrasiTransaksi() async {
    for (final t in transaksiBox.values.toList()) {
      final petaniId = MongoId.kanonik(t.petaniId);
      final pengepulId = MongoId.kanonik(t.pengepulId);
      if (t.petaniId != petaniId || t.pengepulId != pengepulId) {
        t
          ..petaniId = petaniId
          ..pengepulId = pengepulId;
        await t.save();
      }
    }
  }

  /// Membuka box. Bila gagal, file box disalin dulu ke `hive_karantina/`, baru
  /// dihapus dan dibuat ulang.
  ///
  /// Penyebab tersering kegagalan di sini adalah salah skema adapter, bukan
  /// korupsi, karena Hive sudah memulihkan checksum rusak sendiri. Jadi datanya
  /// masih bisa diselamatkan dengan adapter yang benar, dan tidak boleh hilang.
  Future<void> _openBoxSafe<T>(String boxName) async {
    try {
      await Hive.openBox<T>(boxName);
    } on FileSystemException {
      rethrow; // I/O sementara atau disk penuh: jangan hapus apa pun.
    } catch (e) {
      final salinan = await _karantina(boxName);
      if (salinan == null) rethrow; // Gagal menyalin: JANGAN hapus.

      debugPrint('[HiveService] Box $boxName gagal dibuka (${e.runtimeType}). '
          'Dicadangkan ke ${salinan.path}');
      await Hive.deleteBoxFromDisk(boxName);
      await Hive.openBox<T>(boxName);
      _dikarantina.add(boxName);
    }
  }

  /// Menyalin file box tanpa `.lock`. Mengembalikan null bila salinan yang utuh
  /// tidak bisa dipastikan ada.
  Future<File?> _karantina(String boxName) async {
    try {
      final folderHive =
          _testPath ?? (await getApplicationDocumentsDirectory()).path;
      // Hive menyimpan file box dengan nama huruf kecil.
      final nama = boxName.toLowerCase();
      final sumber = File(p.join(folderHive, '$nama.hive'));
      if (!await sumber.exists()) return null;

      final folder = Directory(p.join(folderHive, _folderKarantina));
      await folder.create(recursive: true);

      final salinan =
          await sumber.copy(p.join(folder.path, '${nama}_${_stempel(jam())}.hive'));
      if (await salinan.length() != await sumber.length()) return null;

      await _pangkasKarantina(folder, nama);
      return salinan;
    } catch (e) {
      debugPrint('[HiveService] Gagal mencadangkan $boxName: ${e.runtimeType}');
      return null;
    }
  }

  Future<void> _pangkasKarantina(Directory folder, String nama) async {
    try {
      final pola = RegExp('^${RegExp.escape(nama)}_\\d{8}_\\d{6}\\.hive\$');
      final salinan = await folder
          .list()
          .where((e) => e is File && pola.hasMatch(p.basename(e.path)))
          .toList();
      // Nama memuat stempel waktu tetap lebar, jadi urut nama sama dengan urut waktu.
      salinan.sort((a, b) => p.basename(b.path).compareTo(p.basename(a.path)));
      for (final lama in salinan.skip(_batasSalinanKarantina)) {
        await lama.delete();
      }
    } catch (e) {
      // Salinan berlebih tidak membahayakan data, jadi tidak perlu menggagalkan init.
      debugPrint('[HiveService] Gagal memangkas karantina: ${e.runtimeType}');
    }
  }

  static String _stempel(DateTime t) {
    String dua(int n) => n.toString().padLeft(2, '0');
    return '${t.year.toString().padLeft(4, '0')}${dua(t.month)}${dua(t.day)}'
        '_${dua(t.hour)}${dua(t.minute)}${dua(t.second)}';
  }

  Future<void> _beritahuKarantina() async {
    for (final boxName in _dikarantina) {
      final label = boxName.replaceAll('Box', '');
      try {
        await NotificationService().addNotification(
          judul: 'Data Lokal Bermasalah',
          pesan: 'Data lokal $label bermasalah dan telah dicadangkan. Hubungi admin.',
          tipe: 'sync',
        );
      } catch (e) {
        debugPrint('[HiveService] Gagal membuat notifikasi karantina: ${e.runtimeType}');
      }
    }
  }

  Box<UserHiveModel> get usersBox => Hive.box<UserHiveModel>(_usersBoxName);
  Box<PetaniHiveModel> get petaniBox => Hive.box<PetaniHiveModel>(_petaniBoxName);
  Box<KomoditasHiveModel> get komoditasBox => Hive.box<KomoditasHiveModel>(_komoditasBoxName);
  Box<TransaksiHiveModel> get transaksiBox => Hive.box<TransaksiHiveModel>(_transaksiBoxName);
  Box<NotifikasiHiveModel> get notifikasiBox => Hive.box<NotifikasiHiveModel>('notifikasiBox');
  Box get settingsBox => Hive.box(_settingsBoxName);
  
  bool isFirstTime() {
    final hasOnboarded = settingsBox.get('hasOnboarded', defaultValue: false);
    return !hasOnboarded;
  }

  Future<void> completeOnboarding() async {
    await settingsBox.put('hasOnboarded', true);
  }

  Future<void> saveTransaksi(TransaksiHiveModel transaksi) async {
    await transaksiBox.put(transaksi.idLokal, transaksi);
    
    NotificationService().addNotification(
      judul: 'Transaksi Tersimpan',
      pesan: 'Data ${transaksi.namaKomoditas} (${transaksi.berat.toInt()} kg) tersimpan di perangkat. Jangan lupa sinkronisasi saat online.',
      tipe: 'sync',
    );
  }

  List<TransaksiHiveModel> getPendingTransaksi() {
    return transaksiBox.values
        .where((t) => t.statusSinkronisasi == 'pending')
        .toList();
  }

  List<TransaksiHiveModel> getPendingUpdateTransaksi() {
    return transaksiBox.values
        .where((t) => t.statusSinkronisasi == 'pending_update')
        .toList();
  }

  List<TransaksiHiveModel> getPendingDeleteTransaksi() {
    return transaksiBox.values
        .where((t) => t.statusSinkronisasi == 'pending_delete')
        .toList();
  }

  Future<void> clearAllData() async {
    await usersBox.clear();
    await petaniBox.clear();
    await komoditasBox.clear();
    await transaksiBox.clear();
    await notifikasiBox.clear();
    await settingsBox.clear();
  }

  List<Map<String, dynamic>> exportTransaksiToJson() {
    return transaksiBox.values.map((t) => {
      'idLokal': t.idLokal,
      'petani': t.namaPetani,
      'komoditas': t.namaKomoditas,
      'total': t.totalBayar,
      'status': t.statusSinkronisasi,
    }).toList();
  }
}