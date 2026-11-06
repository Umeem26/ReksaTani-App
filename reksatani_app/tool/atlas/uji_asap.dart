// Skrip ini memang menyentuh jaringan dan berada di luar `test/`, jadi aturan untuk
// kode aplikasi tidak berlaku di sini.
// ignore_for_file: avoid_print, invalid_use_of_visible_for_testing_member, implementation_imports

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mongo_dart/mongo_dart.dart' show Db, ObjectId, where;
import 'package:mongo_dart/src/database/commands/query_and_write_operation_commands/return_classes/write_result.dart';
import 'package:reksatani_app/features/manajer_dashboard/controllers/manajemen_pengepul_controller.dart';
import 'package:reksatani_app/features/transaksi_luring/controllers/transaksi_controller.dart';
import 'package:reksatani_app/models/hive/komoditas_hive_model.dart';
import 'package:reksatani_app/models/hive/user_hive_model.dart';
import 'package:reksatani_app/services/hive_service.dart';
import 'package:reksatani_app/services/master_data_service.dart';
import 'package:reksatani_app/services/mongodb_service.dart';
import 'package:reksatani_app/services/saldo/transaksi_ledger_service.dart';
import 'package:reksatani_app/services/sync/mongo_id.dart';
import 'package:reksatani_app/services/sync/mongo_remote.dart';
import 'package:reksatani_app/services/sync/sync_engine.dart';
import 'package:reksatani_app/services/sync/sync_remote.dart';

/// Uji asap terhadap Atlas sungguhan, lewat `MongoRemote` dan `SyncEngine` asli.
///
///   ASAP_KONFIRMASI=1 MONGO_URI=... flutter test --no-pub tool/atlas/uji_asap.dart
///
/// Tanpa `ASAP_KONFIRMASI=1` hanya mencetak rencana dan tidak tersambung.
///
/// Dijalankan dengan `flutter test` karena `SyncEngine` mengimpor Flutter, sehingga
/// tidak bisa berjalan dengan `dart` biasa. `flutter_test_config.dart` berlaku per
/// folder sampai root proyek, jadi tidak terpakai di `tool/`; skrip memeriksanya.
/// Tes di `test/` tetap terblokir (`test/services/penjaga_jaringan_test.dart`).
///
/// Hanya menulis dokumen `asap-` milik satu kali jalan, dan menghapusnya di akhir.
/// URI, host, dan kredensial tidak pernah dicetak.
void main() {
  test('uji asap Atlas', () async {
    if (HttpOverrides.current != null) {
      fail('flutter_test_config terpakai: jalankan dari tool/atlas, bukan test/.');
    }
    print('flutter_test_config: tidak terpakai (HttpOverrides kosong)');

    if (Platform.environment['ASAP_KONFIRMASI'] != '1') {
      print('DRY-RUN: tidak tersambung. Atur ASAP_KONFIRMASI=1 untuk menjalankan.');
      return;
    }
    final uri = Platform.environment['MONGO_URI'] ?? '';
    if (uri.isEmpty) fail('MONGO_URI belum diatur.');

    await _UjiAsap(uri).jalankan();
  }, timeout: Timeout.none);
}

// ── Penyaring keluaran ──────────────────────────────────────────────

class _Penyaring {
  _Penyaring(String uri) {
    _rahasia.add(uri);
    final m = RegExp(r'^[a-zA-Z+]+://(?:([^:@/]+)(?::([^@/]*))?@)?([^/?]+)')
        .firstMatch(uri);
    if (m == null) return;
    for (final bagian in [m.group(1), m.group(2)]) {
      if (bagian == null || bagian.length < 4) continue;
      _rahasia
        ..add(bagian)
        ..add(Uri.decodeComponent(bagian));
    }
    for (final h in (m.group(3) ?? '').split(',')) {
      final nama = h.split(':').first;
      if (nama.isNotEmpty) _rahasia.add(nama);
    }
  }

  final Set<String> _rahasia = {};

  String bersih(String s) {
    var hasil = s;
    for (final r in _rahasia) {
      hasil = hasil.replaceAll(r, '[DISEMBUNYIKAN]');
    }
    return hasil
        .replaceAll(RegExp(r'mongodb(\+srv)?://\S+'), '[URI-DISEMBUNYIKAN]')
        .replaceAll(
            RegExp(r'[\w.-]+\.mongodb\.net(:\d+)?'), '[HOST-DISEMBUNYIKAN]');
  }
}

// ── Pagar tulisan ───────────────────────────────────────────────────

class _TulisanDitolak implements Exception {
  _TulisanDitolak(this.filter);

  final Object? filter;

  @override
  String toString() => 'Tulisan ditolak pagar, filter bukan dokumen asap: $filter';
}

/// Dokumen milik satu kali jalan: string `asap-...<run>`, atau ObjectId yang tercatat.
class _DokumenMilik {
  _DokumenMilik(this.run);

  final String run;
  final Set<String> _oid = {};

  void catat(ObjectId id) => _oid.add(id.oid);

  bool _nilaiMilik(Object? v) {
    if (v is ObjectId) return _oid.contains(v.oid);
    if (v is! String) return false;
    // `kasbon_<id agen>_<milidetik>` adalah id_lokal buatan aplikasi untuk pencairan.
    final prefiksSah = v.startsWith('asap-') || v.startsWith('kasbon_asap-');
    if (prefiksSah && v.contains(run)) return true;
    return _oid.contains(MongoId.kanonik(v));
  }

  /// Filter harus menyebut `_id` atau `id_lokal` secara persis atau lewat `$in`, dan
  /// semua nilainya milik skrip ini. Selain itu ditolak sebelum menghubungi server.
  void pastikan(Map<String, dynamic> filter) {
    for (final kunci in const ['_id', 'id_lokal']) {
      if (!filter.containsKey(kunci)) continue;
      final v = filter[kunci];
      final nilai = switch (v) {
        Map(length: 1) when v[r'$in'] is List => v[r'$in'] as List,
        Map() => const <Object?>[null],
        _ => <Object?>[v],
      };
      if (nilai.isNotEmpty && nilai.every(_nilaiMilik)) return;
      break;
    }
    throw _TulisanDitolak(filter);
  }
}

/// `MongoRemote` asli, dengan pagar dan catatan semua tulisan.
class _Pagar implements SyncRemote {
  _Pagar(this._asli, this._milik);

  final SyncRemote _asli;
  final _DokumenMilik _milik;
  final List<String> jejak = [];
  int ditolak = 0;

  void _periksa(Map<String, dynamic> filter) {
    try {
      _milik.pastikan(filter);
    } on _TulisanDitolak {
      ditolak++;
      rethrow;
    }
  }

  @override
  Future<bool> ping() => _asli.ping();

  @override
  Future<List<Map<String, dynamic>>> find(
    String koleksi,
    Map<String, dynamic> filter, {
    List<String>? fields,
  }) =>
      _asli.find(koleksi, filter, fields: fields);

  @override
  Future<RemoteWrite> updateOne(
    String koleksi,
    Map<String, dynamic> filter,
    Map<String, dynamic> update, {
    bool upsert = false,
  }) async {
    _periksa(filter);
    final hasil = await _asli.updateOne(koleksi, filter, update, upsert: upsert);
    jejak.add('updateOne $koleksi upsert=$upsert -> $hasil');
    return hasil;
  }

  @override
  Future<RemoteWrite> deleteOne(
    String koleksi,
    Map<String, dynamic> filter,
  ) async {
    _periksa(filter);
    final hasil = await _asli.deleteOne(koleksi, filter);
    jejak.add('deleteOne $koleksi -> $hasil');
    return hasil;
  }
}

// ── Perangkat ───────────────────────────────────────────────────────

/// Satu HP. `HiveService` adalah singleton, jadi hanya satu yang aktif.
class _Hp {
  _Hp(this.id, this.role, this.remote);

  final String id;
  final String role;
  final SyncRemote remote;
  final hive = HiveService();
  Directory? _folder;

  Future<void> pasang() async {
    _folder = await Directory.systemTemp.createTemp('asap');
    await aktifkan();
    await hive.usersBox.put(
      'currentUser',
      UserHiveModel(
        id: id,
        username: id,
        passwordHash: '',
        role: role,
        sisaUangJalan: 0,
        waktuDibuat: DateTime.now(),
      ),
    );
  }

  Future<void> aktifkan() async {
    await Hive.close();
    await hive.init(testPath: _folder!.path);
    MasterDataService().engine = SyncEngine(
      remote: remote,
      hive: hive,
      unggahFoto: (_) async => null,
    );
    MasterDataService().isSyncing = false;
  }

  Future<void> hancurkan() async {
    final folder = _folder;
    if (folder != null && folder.existsSync()) {
      await folder.delete(recursive: true);
    }
  }
}

Future<void> _tungguSync() async {
  while (MasterDataService().isSyncing) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

// ── Uji ─────────────────────────────────────────────────────────────

class _GagalUji implements Exception {
  _GagalUji(this.pesan);

  final String pesan;

  @override
  String toString() => pesan;
}

class _UjiAsap {
  _UjiAsap(this._uri)
      : _penyaring = _Penyaring(_uri),
        run = '${DateTime.now().millisecondsSinceEpoch}',
        oidPetani = ObjectId() {
    _milik = _DokumenMilik(run)..catat(oidPetani);
    _remote = _Pagar(MongoRemote(), _milik);
    _agen = _Hp(idAgen, 'pengepul', _remote);
    _manajer = _Hp('asap-manajer-$run', 'manager', _remote);
  }

  final String _uri;
  final _Penyaring _penyaring;
  final String run;
  final ObjectId oidPetani;

  late final _DokumenMilik _milik;
  late final _Pagar _remote;
  late final _Hp _agen;
  late final _Hp _manajer;

  String get idAgen => 'asap-agen-$run';
  String get idPetani => 'asap-petani-$run';

  static const _koleksiSaldo = ['transaksi', 'petani', 'users'];
  static const _kunciBalasan = [
    'ok',
    'n',
    'nModified',
    'upserted',
    'writeErrors',
    'writeConcernError',
    'code',
    'codeName',
    'errmsg',
  ];

  final _ctrl = TransaksiController();
  final _ledger = TransaksiLedgerService();

  late final _komoditas = KomoditasHiveModel(
    id: 'asap-komoditas-$run',
    namaKomoditas: 'asap-komoditas',
    unitSatuan: 'kg',
    gradeKualitas: const [
      {'grade': 'A', 'harga_maks': 100000000.0},
    ],
    diperbaruiOleh: '',
    waktuPembaruan: DateTime.now(),
  );

  void _tulis(String s) => print(_penyaring.bersih(s));
  void _judul(String s) => _tulis('\n== $s');

  void _cek(String label, Object? nyata, Object? harapan) {
    if (nyata != harapan) {
      throw _GagalUji('$label: nyata $nyata, harapan $harapan');
    }
    _tulis('  lulus: $label = $nyata');
  }

  Map<String, Object?> _ringkas(Map balasan) => {
        'semua_kunci': balasan.keys.toList(),
        for (final k in _kunciBalasan)
          if (balasan.containsKey(k)) k: balasan[k],
      };

  /// Balasan server yang sebenarnya, dan hasil pemetaan `MongoRemote` atasnya.
  WriteResult _cetakBalasan(String label, WriteResult h) {
    _tulis('  BALASAN $label: ${_ringkas(h.serverResponses.first)}');
    _tulis('    petakan -> ${MongoRemote.petakan(h)}');
    return h;
  }

  Future<WriteResult> _updateMentah(
    String label,
    String koleksi,
    Map<String, dynamic> filter,
    Map<String, dynamic> update, {
    bool upsert = false,
  }) async {
    _milik.pastikan(filter);
    final h = await MongoDatabase.getCollection(koleksi)
        .updateOne(filter, update, upsert: upsert);
    return _cetakBalasan(label, h);
  }

  Object? _idUpsert(WriteResult h) {
    final daftar = h.serverResponses.first['upserted'];
    if (daftar is! List || daftar.isEmpty) return null;
    return (daftar.first as Map)['_id'];
  }

  void _cetakJejak() {
    for (final j in _remote.jejak) {
      _tulis('  $j');
    }
    _remote.jejak.clear();
  }

  Future<Map<String, dynamic>> _dok(String koleksi, Object id) async {
    final docs = await _remote.find(koleksi, {'_id': id});
    if (docs.length != 1) {
      throw _GagalUji('$koleksi/$id: ${docs.length} dokumen');
    }
    return docs.first;
  }

  Future<List<Map<String, dynamic>>> _transaksiAsap() => _remote.find(
        'transaksi',
        {
          'id_lokal': {r'$regex': '^$idAgen'},
        },
      );

  Future<Map<String, int>> _hitungSemua() async => {
        for (final k in const ['komoditas', 'petani', 'transaksi', 'users'])
          k: (await _remote.find(k, {}, fields: const ['_id'])).length,
      };

  Future<void> _sinkron(String label) async {
    await _tungguSync();
    await MasterDataService().syncAll();
    _periksaLaporan(label);
  }

  void _periksaLaporan(String label) {
    final l = MasterDataService().laporanTerakhir!;
    _tulis('  sync $label: terkirim ${l.terkirim}, riwayatBaru ${l.riwayatBaru}');
    _cek('$label: masalah', '${l.masalah}', '[]');
    _cek('$label: menunggu', MasterDataService().jumlahMenunggu, 0);
  }

  Future<void> _cekSaldo(
    String label, {
    required double kasbonString,
    required double kasbonOid,
    required double kas,
  }) async {
    _cek('$label: kasbon cloud _id string',
        (await _dok('petani', idPetani))['sisa_hutang_kasbon'], kasbonString);
    _cek('$label: kasbon cloud _id ObjectId',
        (await _dok('petani', oidPetani))['sisa_hutang_kasbon'], kasbonOid);
    _cek('$label: kas cloud',
        (await _dok('users', idAgen))['sisa_uang_jalan'], kas);
    _cek('$label: kasbon HP _id string',
        _agen.hive.petaniBox.get(idPetani)!.sisaHutangKasbon, kasbonString);
    _cek('$label: kasbon HP _id ObjectId',
        _agen.hive.petaniBox.get(oidPetani.oid)!.sisaHutangKasbon, kasbonOid);
    _cek('$label: kas HP', _agen.hive.usersBox.get('currentUser')!.sisaUangJalan,
        kas);
  }

  Future<String> _beli(Object? idPetaniHive, String harga) async {
    final hive = _agen.hive;
    final lama = hive.transaksiBox.keys.toSet();
    await _ctrl.simpanTransaksi(
      petaniTerpilih: idPetaniHive == null ? null : hive.petaniBox.get(idPetaniHive),
      namaPenjual: 'asap-penjual',
      komoditasTerpilih: _komoditas,
      gradeTerpilih: 'A',
      beratText: '1',
      hargaText: harga,
      fotoNotaPath: '',
      fotoBarangPath: '',
      izinkanTanpaFoto: true,
    );
    await _tungguSync();
    _periksaLaporan('simpan $harga');
    return hive.transaksiBox.keys
        .cast<String>()
        .firstWhere((k) => !lama.contains(k));
  }

  // ── Langkah ──

  Future<void> jalankan() async {
    MongoDatabase.pembuka = () async {
      final db = await Db.create(_uri);
      await db.open();
      _db = db;
      return db;
    };

    Object? kegagalan;
    try {
      await MongoDatabase.connect();
      await _langkahServer();
      await _langkahTanam();
      await _langkahPembelian();
      await _langkahManajer();
      await _langkahDuplikat();
      await _langkahFilterIn();
      await _langkahUpsertIn();
      await _langkahNMatched();
      await _langkahProjection();
      await _langkahTanpaPetani();
      await _langkahPencairan();
    } catch (e) {
      kegagalan = e;
      _tulis('\nGAGAL: ${e is Map ? _ringkas(e) : e}');
    }

    final bersih = await _bersihkan();
    await MongoDatabase.close();
    await Hive.close();
    await _agen.hancurkan();
    await _manajer.hancurkan();

    if (kegagalan != null) {
      fail(_penyaring.bersih('Uji asap gagal: $kegagalan'));
    }
    if (!bersih) fail('Uji asap lulus, tetapi pembersihan tidak tuntas.');
    _tulis('\nSEMUA LANGKAH LULUS');
  }

  Db? _db;
  Map<String, int> _awal = const {};

  Future<void> _langkahServer() async {
    _judul('0. Server (U13) dan ping (U16)');
    _tulis('Database: ${_db!.databaseName}');
    final info = await _db!.runCommand({'buildInfo': 1});
    _tulis('Versi server: ${info['version']}');
    _tulis('fcv driver: ${_db!.masterConnection.serverCapabilities.fcv}');
    for (final info in await _db!.getCollectionInfos()) {
      final opsi = info['options'];
      _tulis('Validator ${info['name']}: '
          '${opsi is Map ? opsi['validator'] : null}, '
          'level ${opsi is Map ? opsi['validationLevel'] : null}, '
          'aksi ${opsi is Map ? opsi['validationAction'] : null}');
    }

    _cek('MongoRemote.ping', await _remote.ping(), true);
    final ping = await MongoDatabase.getCollection('users')
        .findOne(where.fields(['_id']));
    _cek('findOne(where.fields) mengembalikan hanya', '${ping?.keys.toList()}',
        '[_id]');

    _awal = await _hitungSemua();
    _tulis('Hitungan awal: $_awal');
    for (final k in _koleksiSaldo) {
      final sisa = await _remote.find(
        k,
        {
          r'$or': [
            {
              'id_lokal': {r'$regex': '^asap-'},
            },
            {
              '_id': {r'$regex': '^asap-'},
            },
            {
              'asap_run': {r'$exists': true},
            },
          ],
        },
        fields: const ['_id'],
      );
      _tulis('Sisa asap lama di $k: ${sisa.length}');
    }

    _judul('0b. Pagar menolak filter lain, sebelum menghubungi server');
    for (final filter in <Map<String, dynamic>>[
      {'_id': 'bukan-asap-$run'},
      {'role': 'asap-tidak-ada'},
      {
        '_id': {r'$ne': 'asap-$run'},
      },
    ]) {
      try {
        await _remote.updateOne('users', filter, {
          r'$set': {'asap_x': 1},
        });
        throw _GagalUji('Pagar meloloskan $filter');
      } on _TulisanDitolak {
        _tulis('  ditolak: $filter');
      }
    }
    _remote.ditolak = 0;
  }

  Future<void> _langkahTanam() async {
    _judul('1. Tanam agen dan petani: upsert filter eq (U5, U6)');
    await _updateMentah('upsert users _id string', 'users', {'_id': idAgen}, {
      r'$setOnInsert': {
        'username': idAgen,
        'password_hash': 'asap-bukan-hash',
        'role': 'pengepul',
        'saldo_dasar_uang_jalan': 1000000.0,
        'sisa_uang_jalan': 1000000.0,
        'waktu_dibuat': DateTime.now().toIso8601String(),
        'asap_run': run,
      },
    }, upsert: true);

    Map<String, dynamic> petani(String nama, double kasbon) => {
          r'$setOnInsert': {
            'nama_petani': nama,
            'desa': 'asap-desa',
            'pengepul_id': idAgen,
            'saldo_dasar_kasbon': kasbon,
            'sisa_hutang_kasbon': kasbon,
            'waktu_dibuat': DateTime.now().toIso8601String(),
            'asap_run': run,
          },
        };

    await _updateMentah('upsert petani _id string', 'petani', {'_id': idPetani},
        petani('asap-petani-string', 200000), upsert: true);
    await _updateMentah('upsert petani _id ObjectId', 'petani',
        {'_id': oidPetani}, petani('asap-petani-oid', 100000), upsert: true);

    _cek('filter eq tersalin: _id string',
        (await _dok('petani', idPetani))['_id'], idPetani);
    _cek('filter eq tersalin: _id ObjectId',
        (await _dok('petani', oidPetani))['_id'], oidPetani);
  }

  Future<void> _langkahPembelian() async {
    await _agen.pasang();

    _judul('2. Sync awal agen: pull modernFind tanpa projection (U16)');
    await _sinkron('awal');
    _cetakJejak();
    final hitung = await _hitungSemua();
    _cek('komoditas di HP', _agen.hive.komoditasBox.length, hitung['komoditas']);
    _cek('petani di HP', _agen.hive.petaniBox.length, hitung['petani']);
    await _cekSaldo('awal', kasbonString: 200000, kasbonOid: 100000, kas: 1000000);

    _judul('3. Simpan pembelian lewat controller + sync');
    final beliString = await _beli(idPetani, '50000');
    _cetakJejak();
    final beliOid = await _beli(oidPetani.oid, '130000');
    _cetakJejak();
    _cek('dokumen transaksi', (await _transaksiAsap()).length, 2);
    await _cekSaldo('sesudah beli', kasbonString: 150000, kasbonOid: 0, kas: 970000);

    _judul('4. Sync ulang: tidak ada tulisan, tidak ada dokumen baru');
    await _sinkron('ulang');
    _cek('jumlah tulisan', _remote.jejak.length, 0);
    _cek('dokumen transaksi', (await _transaksiAsap()).length, 2);
    await _cekSaldo('sync ulang', kasbonString: 150000, kasbonOid: 0, kas: 970000);

    _judul('5. Balasan upsert hilang: baris dikirim lagi');
    final baris = _agen.hive.transaksiBox.get(beliString)!;
    baris.statusSinkronisasi = 'pending';
    await baris.save();
    await _sinkron('kirim ulang');
    _cetakJejak();
    _cek('dokumen transaksi', (await _transaksiAsap()).length, 2);
    await _cekSaldo('kirim ulang', kasbonString: 150000, kasbonOid: 0, kas: 970000);

    _judul('6. Edit: total 50.000 menjadi 230.000');
    await _ctrl.updateTransaksi(
      _agen.hive.transaksiBox.get(beliString)!,
      petaniTerpilih: _agen.hive.petaniBox.get(idPetani),
      namaPenjual: 'asap-penjual',
      komoditasTerpilih: _komoditas,
      gradeTerpilih: 'A',
      beratText: '1',
      hargaText: '230000',
      fotoNotaPath: '',
      fotoBarangPath: '',
    );
    await _tungguSync();
    _periksaLaporan('edit');
    _cetakJejak();
    final diedit = (await _transaksiAsap())
        .firstWhere((d) => d['id_lokal'] == beliString);
    _cek('total_bayar cloud', diedit['total_bayar'], 230000);
    _cek('nominal_potong_kasbon cloud', diedit['nominal_potong_kasbon'], 200000);
    _cek('dokumen transaksi', (await _transaksiAsap()).length, 2);
    await _cekSaldo('sesudah edit', kasbonString: 0, kasbonOid: 0, kas: 940000);

    _judul('7. Hapus pembelian petani ObjectId');
    await _ledger.hapus(_agen.hive.transaksiBox.get(beliOid)!);
    await _sinkron('hapus');
    _cetakJejak();
    _cek('dokumen transaksi', (await _transaksiAsap()).length, 1);
    await _cekSaldo('sesudah hapus',
        kasbonString: 0, kasbonOid: 100000, kas: 970000);

    _judul('7b. Hapus diulang: balasan removed 0');
    _milik.pastikan({'id_lokal': beliOid});
    _cetakBalasan(
      'deleteOne tanpa dokumen',
      await MongoDatabase.getCollection('transaksi')
          .deleteOne({'id_lokal': beliOid}),
    );

    _idLokalTersisa = beliString;
  }

  late String _idLokalTersisa;

  Future<void> _langkahManajer() async {
    _judul('8. Manajer: pull riwayat, lalu top-up 100.000');
    await _manajer.pasang();
    await _sinkron('manajer');
    _cetakJejak();
    _cek('riwayat sampai ke manajer',
        _manajer.hive.transaksiBox.containsKey(_idLokalTersisa), true);

    final ctrl = ManajemenPengepulController(remote: _remote);
    _cek(
      'top-up',
      await ctrl.editPengepul(
        id: idAgen,
        username: idAgen,
        sisaUangJalan: 1070000,
        sisaLama: 970000,
      ),
      HasilEditPengepul.berhasil,
    );
    _cetakJejak();
    final agen = await _dok('users', idAgen);
    _cek('saldo_dasar cloud', agen['saldo_dasar_uang_jalan'], 1100000);
    _cek('sisa cloud', agen['sisa_uang_jalan'], 1070000);

    _judul('8b. Top-up agen yang tidak ada: nMatched 0');
    _cek(
      'top-up tanpa dokumen',
      await ctrl.editPengepul(
        id: 'asap-tidak-ada-$run',
        username: 'asap-tidak-ada-$run',
        sisaUangJalan: 1,
        sisaLama: 0,
      ),
      HasilEditPengepul.tidakDitemukan,
    );
    _cetakJejak();

    _judul('8c. Top-up sampai ke HP agen');
    await _agen.aktifkan();
    await _sinkron('agen sesudah top-up');
    _cek('jumlah tulisan', _remote.jejak.length, 0);
    await _cekSaldo('sesudah top-up',
        kasbonString: 0, kasbonOid: 100000, kas: 1070000);
  }

  Future<void> _langkahDuplikat() async {
    _judul('9. id_lokal ganda: E11000 dan index yang disebut');
    // Salinan dokumen yang sah: `transaksi` punya validator `$jsonSchema`, yang
    // menolak dengan kode 121 sebelum pemeriksaan index.
    final asli = (await _transaksiAsap()).single;
    final isi = {...asli}..remove('_id');
    final dokumen = {...isi, '_id': 'asap-dup-$run'};
    _milik.pastikan(dokumen);
    final sisip = _cetakBalasan(
      'insertOne id_lokal ganda',
      await MongoDatabase.getCollection('transaksi').insertOne(dokumen),
    );
    _cek('insertOne: kode', MongoRemote.petakan(sisip).errorCode, 11000);

    final upsert = await _remote.updateOne(
      'transaksi',
      {'_id': 'asap-dup2-$run'},
      {r'$set': isi},
      upsert: true,
    );
    _cetakJejak();
    _cek('MongoRemote: duplikat', upsert.duplikat, true);
    _cek('MongoRemote: kenaDokumen', upsert.kenaDokumen, false);
    _cek('dokumen transaksi', (await _transaksiAsap()).length, 1);
  }

  Future<void> _langkahFilterIn() async {
    _judul(r'10. Filter $in pada _id ObjectId dan string');
    Future<int> jumlah(Map<String, dynamic> filter) async =>
        (await _remote.find('petani', filter, fields: const ['_id'])).length;

    _cek(r'$in kandidat hex ObjectId', await jumlah(MongoId.filterId(oidPetani.oid)), 1);
    _cek(r'$in kandidat dari ObjectId', await jumlah(MongoId.filterId(oidPetani)), 1);
    _cek(r'$in kandidat literal lama',
        await jumlah(MongoId.filterId('ObjectId("${oidPetani.oid}")')), 1);
    _cek(r'$in kandidat string', await jumlah(MongoId.filterId(idPetani)), 1);
    _cek(
      r'$in campuran',
      await jumlah({
        '_id': {
          r'$in': [...MongoId.kandidat(oidPetani.oid), ...MongoId.kandidat(idPetani)],
        },
      }),
      2,
    );
    _cek(r'$in pengepul_id', await jumlah(MongoId.filterRef('pengepul_id', idAgen)), 2);

    await _updateMentah('updateOne filterId ObjectId', 'petani',
        MongoId.filterId(oidPetani.oid), {
      r'$set': {'asap_cek': run},
    });
    await _updateMentah(
        'updateOne filterId string', 'petani', MongoId.filterId(idPetani), {
      r'$set': {'asap_cek': run},
    });
  }

  Future<void> _langkahUpsertIn() async {
    _judul(r'11. Upsert dengan $in (U6): apa yang menjadi _id');

    Future<Object?> coba(String label, List<String> nilai) async {
      final h = await _updateMentah(
        label,
        'petani',
        {
          '_id': {r'$in': nilai},
        },
        {
          // Lengkap menurut validator, dan bukan milik agen uji.
          r'$setOnInsert': {
            'nama_petani': 'asap-upsert-in',
            'desa': 'asap-desa',
            'pengepul_id': 'asap-tidak-ada-$run',
            'saldo_dasar_kasbon': 0.0,
            'sisa_hutang_kasbon': 0.0,
            'asap_run': run,
          },
        },
        upsert: true,
      );
      final id = _idUpsert(h);
      _tulis('  _id baru: $id (${id.runtimeType})');
      if (id is ObjectId) _milik.catat(id);
      if (id != null) {
        final hapus = await _remote.deleteOne('petani', {'_id': id});
        _cek('$label: terhapus lagi', hapus.removed, 1);
      }
      _cetakJejak();
      return id;
    }

    _cek(r'$in satu nilai: nilainya tersalin menjadi _id',
        await coba(r'$in satu nilai', ['asap-in1-$run']), 'asap-in1-$run');
    final idDua =
        await coba(r'$in dua nilai', ['asap-in2a-$run', 'asap-in2b-$run']);
    _cek(r'$in dua nilai: _id baru yang bukan kandidat', idDua is ObjectId, true);
  }

  Future<void> _langkahNMatched() async {
    _judul('12. Bentuk nMatched');
    await _updateMentah('update tanpa dokumen', 'petani',
        {'_id': 'asap-tidak-ada-$run'}, {
      r'$set': {'asap_cek': run},
    });
    await _updateMentah(
        'update nilai sama', 'petani', {'_id': idPetani}, {
      r'$set': {'asap_cek': run},
    });

    // Validator `petani`: minimum 0. `_tulisSaldo` bisa menulis kasbon negatif.
    final negatif = await _updateMentah(
        'kasbon negatif ke validator', 'petani', {'_id': idPetani}, {
      r'$set': {'sisa_hutang_kasbon': -1.0},
    });
    _cek('kasbon negatif: kode', MongoRemote.petakan(negatif).errorCode, 121);
  }

  Future<void> _langkahProjection() async {
    _judul('13. modernFind dengan projection (U16)');
    final docs = await _remote.find(
      'users',
      {'_id': idAgen},
      fields: const ['username', 'sisa_uang_jalan'],
    );
    _cek('field yang kembali', '${docs.single.keys.toList()..sort()}',
        '[_id, sisa_uang_jalan, username]');
    _cek('password_hash tidak ikut', docs.single.containsKey('password_hash'), false);
  }

  Future<void> _langkahTanpaPetani() async {
    _judul('14. Pembelian tanpa petani: petani_id kosong ke validator');
    await _beli(null, '10000');
    _cetakJejak();
    _cek('dokumen transaksi', (await _transaksiAsap()).length, 2);
    await _cekSaldo('tanpa petani',
        kasbonString: 0, kasbonOid: 100000, kas: 1060000);
  }

  /// Langkah terakhir, karena validator `transaksi` hanya menerima grade A, B, C,
  /// sedangkan aplikasi menulis `-` untuk pencairan. Skrip memang harus gagal di
  /// sini sampai salah satunya berubah.
  Future<void> _langkahPencairan() async {
    _judul('15. Pencairan kasbon 30.000 lewat controller + sync');
    final hive = _agen.hive;
    final lama = hive.transaksiBox.keys.toSet();
    await _ctrl.simpanKasbonMurni(
      petaniTerpilih: hive.petaniBox.get(idPetani)!,
      nominalKasbonText: '30000',
    );
    await _tungguSync();
    _cetakJejak();

    final id = hive.transaksiBox.keys
        .cast<String>()
        .firstWhere((k) => !lama.contains(k));
    final baris = hive.transaksiBox.get(id)!;
    final laporan = MasterDataService().laporanTerakhir!;
    _tulis('  masalah: ${laporan.masalah}');
    _tulis('  HP: status ${baris.statusSinkronisasi}, '
        'grade "${baris.gradeTerpilih}", '
        'kasbon ${hive.petaniBox.get(idPetani)!.sisaHutangKasbon}, '
        'kas ${hive.usersBox.get('currentUser')!.sisaUangJalan}');
    final cloud = await _remote.find('transaksi', {'id_lokal': id});
    _tulis('  cloud: dokumen ${cloud.length}, '
        'kasbon ${(await _dok('petani', idPetani))['sisa_hutang_kasbon']}, '
        'kas ${(await _dok('users', idAgen))['sisa_uang_jalan']}');

    if (cloud.isEmpty) {
      await _updateMentah(
        'pencairan apa adanya',
        'transaksi',
        {'id_lokal': id},
        SyncEngine.bangunUpdateTransaksi(baris, DateTime.now()),
        upsert: true,
      );
    }

    _cek('pencairan sampai ke cloud', cloud.length, 1);
    _cek('pencairan: masalah', '${laporan.masalah}', '[]');
    await _cekSaldo('sesudah pencairan',
        kasbonString: 30000, kasbonOid: 100000, kas: 1030000);
  }

  // ── Pembersihan ──

  /// Selalu berjalan, juga setelah kegagalan. Dokumen dicari dari penanda run ini,
  /// lalu dihapus satu per satu lewat pagar.
  Future<bool> _bersihkan() async {
    _judul('Pembersihan');
    try {
      await _tungguSync();
      if (!await _remote.ping()) {
        _tulis('Tidak tersambung saat membersihkan. Sisa ditandai asap_run: $run');
        return false;
      }

      Future<List<Map<String, dynamic>>> sisa(String koleksi) => _remote.find(
            koleksi,
            {
              r'$or': [
                {'asap_run': run},
                {
                  'id_lokal': {r'$regex': '^(kasbon_)?asap-.*$run'},
                },
                {
                  '_id': {r'$regex': '^asap-.*$run'},
                },
              ],
            },
            fields: const ['_id'],
          );

      for (final k in _koleksiSaldo) {
        final docs = await sisa(k);
        var terhapus = 0;
        for (final d in docs) {
          final id = d['_id'] as Object;
          if (id is ObjectId) _milik.catat(id);
          final hasil = await _remote.deleteOne(k, {'_id': id});
          terhapus += hasil.removed;
        }
        _tulis('$k: dihapus $terhapus dari ${docs.length}');
      }
      _remote.jejak.clear();

      var tuntas = true;
      for (final k in _koleksiSaldo) {
        final tertinggal = (await sisa(k)).length;
        if (tertinggal > 0) {
          tuntas = false;
          _tulis('TERTINGGAL di $k: $tertinggal, penanda asap_run: $run');
        }
      }
      final akhir = await _hitungSemua();
      _tulis('Hitungan akhir: $akhir');
      if (_awal.isNotEmpty && '$akhir' != '$_awal') {
        _tulis('PERHATIAN: hitungan berbeda dari awal $_awal. Ada penulis lain, '
            'atau pembersihan tidak tuntas.');
      }
      _tulis('Tulisan ditolak pagar selama skenario: ${_remote.ditolak}');
      return tuntas && _remote.ditolak == 0;
    } catch (e) {
      _tulis('Pembersihan gagal: ${e is Map ? _ringkas(e) : e}. '
          'Sisa ditandai asap_run: $run');
      return false;
    }
  }
}
