// Entrypoint khusus debug untuk mengambil screenshot dengan data FIKTIF.
//
// Jalankan:
//   flutter run -t tool/demo/demo_main.dart --dart-define=DEMO_MODE=pengepul
// DEMO_MODE: onboarding (belum pernah dibuka), login (onboarding selesai,
// belum login), pengepul, atau manajer.
//
// Penjaga jaringan: koneksi MongoDB selalu ditolak dan HTTP hanya diizinkan ke
// tile OpenStreetMap, jadi tidak ada yang sampai ke Atlas atau Cloudinary walau
// env.g.dart berisi kredensial. Semua nama, desa, dan angka di sini rekaan.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:reksatani_app/main.dart' show MyApp;
import 'package:reksatani_app/models/hive/komoditas_hive_model.dart';
import 'package:reksatani_app/models/hive/notifikasi_hive_model.dart';
import 'package:reksatani_app/models/hive/petani_hive_model.dart';
import 'package:reksatani_app/models/hive/transaksi_hive_model.dart';
import 'package:reksatani_app/models/hive/user_hive_model.dart';
import 'package:reksatani_app/services/hive_service.dart';
import 'package:reksatani_app/services/mongodb_service.dart';
import 'package:reksatani_app/services/saldo/kasbon_rules.dart';

const String _mode = String.fromEnvironment('DEMO_MODE', defaultValue: 'pengepul');
const Set<String> _hostDiizinkan = {'tile.openstreetmap.org'};

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Fixture debug, bukan kode produksi: sama dengan penjaga di test/flutter_test_config.dart.
  // ignore: invalid_use_of_visible_for_testing_member
  MongoDatabase.pembuka = () async {
    debugPrint('[demo] koneksi MongoDB diblokir');
    throw StateError('[demo] koneksi MongoDB diblokir');
  };
  HttpOverrides.global = _HanyaTilePeta();

  final hive = HiveService();
  await hive.init();
  await _kosongkan(hive);
  await _isi(hive, DateTime.now());
  runApp(const MyApp());
}

Future<void> _kosongkan(HiveService h) async {
  await h.usersBox.clear();
  await h.petaniBox.clear();
  await h.komoditasBox.clear();
  await h.transaksiBox.clear();
  await h.notifikasiBox.clear();
  await h.settingsBox.delete('hasOnboarded');
}

Future<void> _isi(HiveService h, DateTime now) async {
  if (_mode != 'onboarding') await h.settingsBox.put('hasOnboarded', true);
  await _isiKomoditas(h, now);
  if (_mode == 'onboarding' || _mode == 'login') return;

  final agen = [
    _agen('agen-demo-1', 'Asep', 8750000, now),
    _agen('agen-demo-2', 'Dudung', 5200000, now),
  ];
  // HP agen hanya memegang data miliknya; HP manajer memegang semua.
  final milikSesi = _mode == 'manajer' ? null : agen.first.id;
  bool dipakai(String pengepulId) => milikSesi == null || pengepulId == milikSesi;
  if (milikSesi == null) {
    for (final a in agen) {
      await h.usersBox.put(a.id, a);
    }
  }
  final manajer = UserHiveModel(
    id: 'manajer-demo-1',
    username: 'manajer',
    passwordHash: 'demo',
    role: 'manajer',
    sisaUangJalan: 0,
    waktuDibuat: now.subtract(const Duration(days: 120)),
  );
  // Hive menolak satu objek di dua kunci, jadi sesi memakai salinan.
  final sesi = _mode == 'manajer' ? manajer : agen.first;
  await h.usersBox.put(
    'currentUser',
    UserHiveModel(
      id: sesi.id,
      username: sesi.username,
      passwordHash: sesi.passwordHash,
      role: sesi.role,
      sisaUangJalan: sesi.sisaUangJalan,
      waktuDibuat: sesi.waktuDibuat,
    ),
  );

  final petani = [
    _petani('petani-demo-1', 'Pak Sarmin', 'Sukamukti', 'agen-demo-1', 350000, now),
    _petani('petani-demo-2', 'Bu Euis Rohaeti', 'Cikahuripan', 'agen-demo-1', 0, now),
    _petani('petani-demo-3', 'Pak Ujang Supriatna', 'Mekarwangi', 'agen-demo-1', 1700000, now),
    _petani('petani-demo-4', 'Bu Tarsih', 'Sindangsari', 'agen-demo-1', 150000, now),
    _petani('petani-demo-5', 'Pak Karta', 'Girimulya', 'agen-demo-2', 400000, now),
    _petani('petani-demo-6', 'Bu Iyah', 'Tanjungwangi', 'agen-demo-2', 0, now),
  ];
  for (final p in petani.where((p) => dipakai(p.pengepulId))) {
    await h.petaniBox.put(p.id, p);
  }

  final hariIni = DateTime(now.year, now.month, now.day);
  // Hari ini: 09:30 dianggap "sekarang", supaya waktu tidak pernah di masa depan.
  DateTime jam(int hariLalu, int j, int m) => hariLalu == 0
      ? now.subtract(Duration(minutes: 9 * 60 + 30 - (j * 60 + m)))
      : hariIni.subtract(Duration(days: hariLalu)).add(Duration(hours: j, minutes: m));

  final trx = <TransaksiHiveModel>[
    _beli('w1', agen[0], petani[0], 'Gabah', 'A', 450, 7200, 200000, jam(0, 8, 15), -6.8213, 107.5512, 'synced'),
    _beli('w2', agen[0], petani[1], 'Kopi Robusta', 'B', 62, 37000, 0, jam(0, 7, 40), -6.8302, 107.5655, 'synced'),
    _beli('w3', agen[0], petani[3], 'Sawit', 'C', 1250, 1950, 150000, jam(0, 9, 5), null, null, 'pending',
        statusFoto: 'pending'),
    _pencairan('w4', agen[0], petani[2], 500000, jam(1, 16, 20), -6.8401, 107.5433, 'pending'),
    _beli('w5', agen[0], petani[2], 'Gabah', 'B', 300, 6700, 0, jam(1, 10, 30), -6.8395, 107.5440, 'synced'),
    _beli('w6', agen[0], petani[1], 'Kopi Robusta', 'A', 40, 41500, 0, jam(2, 13, 0), -6.8299, 107.5661, 'synced'),
    _beli('w7', agen[0], petani[0], 'Gabah', 'A', 520, 7300, 100000, jam(4, 8, 45), -6.8220, 107.5520, 'synced'),
    _beli('d1', agen[1], petani[4], 'Sawit', 'A', 2100, 2750, 0, jam(0, 10, 10), -6.7950, 107.6102, 'synced'),
    _beli('d2', agen[1], petani[4], 'Sawit', 'B', 1800, 2350, 200000, jam(2, 9, 30), -6.7988, 107.6150, 'synced'),
    _beli('r1', agen[1], petani[5], 'Kopi Robusta', 'A', 85, 41000, 0, jam(1, 11, 0), -6.8605, 107.5208, 'synced'),
    _beli('r2', agen[1], petani[5], 'Gabah', 'C', 380, 5900, 0, jam(3, 14, 15), -6.8650, 107.5250, 'synced'),
  ];
  for (final t in trx.where((t) => dipakai(t.pengepulId))) {
    await h.transaksiBox.put(t.idLokal, t);
  }

  final notif = [
    NotifikasiHiveModel(
        id: 'n1', judul: 'Sinkronisasi tertunda', tipe: 'sync', waktu: jam(0, 9, 6),
        pesan: '2 transaksi menunggu sinyal untuk dikirim ke server.'),
    NotifikasiHiveModel(
        id: 'n2', judul: 'Lokasi tidak tersimpan', tipe: 'info', waktu: jam(0, 9, 5),
        pesan: 'GPS gagal saat mencatat pembelian Sawit dari Bu Tarsih. Transaksi tetap tersimpan.'),
    NotifikasiHiveModel(
        id: 'n3', judul: 'Harga maksimum diperbarui', tipe: 'harga', waktu: jam(1, 7, 0), isRead: true,
        pesan: 'Manajer memperbarui harga maksimum Gabah grade A menjadi Rp7.500/kg.'),
    NotifikasiHiveModel(
        id: 'n4', judul: 'Uang jalan ditambah', tipe: 'saldo', waktu: jam(2, 7, 30), isRead: true,
        pesan: 'Saldo uang jalan Anda bertambah Rp2.000.000.'),
  ];
  for (final n in notif) {
    await h.notifikasiBox.put(n.id, n);
  }
}

Future<void> _isiKomoditas(HiveService h, DateTime now) async {
  const harga = {
    'Gabah': ['kg', 7500.0, 6800.0, 6000.0],
    'Kopi Robusta': ['kg', 42000.0, 38000.0, 34000.0],
    'Sawit': ['kg', 2800.0, 2400.0, 2000.0],
  };
  for (final e in harga.entries) {
    final id = e.key.toLowerCase().replaceAll(' ', '_');
    await h.komoditasBox.put(
      id,
      KomoditasHiveModel(
        id: id,
        namaKomoditas: e.key,
        unitSatuan: e.value[0] as String,
        gradeKualitas: [
          {'grade': 'A', 'harga_maks': e.value[1]},
          {'grade': 'B', 'harga_maks': e.value[2]},
          {'grade': 'C', 'harga_maks': e.value[3]},
        ],
        diperbaruiOleh: 'manajer-demo-1',
        waktuPembaruan: now.subtract(const Duration(days: 1)),
      ),
    );
  }
}

UserHiveModel _agen(String id, String nama, double uangJalan, DateTime now) => UserHiveModel(
      id: id,
      username: nama,
      passwordHash: 'demo',
      role: 'pengepul',
      sisaUangJalan: uangJalan,
      waktuDibuat: now.subtract(const Duration(days: 90)),
    );

PetaniHiveModel _petani(String id, String nama, String desa, String agenId, double kasbon, DateTime now) =>
    PetaniHiveModel(
      id: id,
      namaPetani: nama,
      desa: desa,
      pengepulId: agenId,
      sisaHutangKasbon: kasbon,
      waktuDibuat: now.subtract(const Duration(days: 60)),
    );

TransaksiHiveModel _beli(String kode, UserHiveModel agen, PetaniHiveModel petani, String komoditas,
        String grade, double berat, double harga, double potong, DateTime waktu, double? lat, double? lng,
        String status, {String statusFoto = 'ok'}) =>
    TransaksiHiveModel(
      idLokal: '${agen.id}_demo_$kode',
      id: status == 'synced' ? 'demo-$kode' : null,
      pengepulId: agen.id,
      petaniId: petani.id,
      namaPengepul: agen.username,
      namaPetani: petani.namaPetani,
      namaKomoditas: komoditas,
      gradeTerpilih: grade,
      berat: berat,
      hargaBeliSatuan: harga,
      nominalPotongKasbon: potong,
      totalBayar: berat * harga - potong,
      fotoFisikBarang: '',
      fotoNota: '',
      latitude: lat,
      longitude: lng,
      statusSinkronisasi: status,
      createdAt: waktu,
      waktuDisinkron: status == 'synced' ? waktu.add(const Duration(minutes: 3)) : null,
      isManualGrading: true,
      statusFoto: statusFoto,
      saranKomoditasAi: komoditas.toLowerCase().contains('kopi')
          ? 'kopi'
          : komoditas == 'Sawit'
              ? 'kelapa_sawit'
              : 'gabah',
      rubrikVersi: 'v0.1-draf',
    );

TransaksiHiveModel _pencairan(String kode, UserHiveModel agen, PetaniHiveModel petani, double nominal,
        DateTime waktu, double? lat, double? lng, String status) =>
    TransaksiHiveModel(
      idLokal: 'kasbon_${agen.id}_demo_$kode',
      pengepulId: agen.id,
      petaniId: petani.id,
      namaPengepul: agen.username,
      namaPetani: petani.namaPetani,
      namaKomoditas: KasbonRules.labelPencairan,
      gradeTerpilih: '-',
      berat: 0,
      hargaBeliSatuan: 0,
      nominalPotongKasbon: 0,
      totalBayar: nominal,
      fotoFisikBarang: '',
      fotoNota: '',
      latitude: lat,
      longitude: lng,
      statusSinkronisasi: status,
      createdAt: waktu,
    );

/// HTTP hanya ke tile peta. Semua host lain (termasuk Cloudinary) ditolak.
class _HanyaTilePeta extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.connectionFactory = (Uri url, String? proxyHost, int? proxyPort) {
      if (!_hostDiizinkan.contains(url.host)) {
        debugPrint('[demo] HTTP diblokir ke host lain');
        throw StateError('[demo] HTTP diblokir');
      }
      return url.scheme == 'https'
          ? SecureSocket.startConnect(url.host, url.port, context: context)
          : Socket.startConnect(url.host, url.port);
    };
    return client;
  }
}
