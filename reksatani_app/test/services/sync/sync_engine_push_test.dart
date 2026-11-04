import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;
import 'package:reksatani_app/models/hive/transaksi_hive_model.dart';
import 'package:reksatani_app/models/hive/user_hive_model.dart';
import 'package:reksatani_app/services/hive_service.dart';
import 'package:reksatani_app/services/master_data_service.dart';
import 'package:reksatani_app/services/sync/sync_engine.dart';
import 'package:reksatani_app/services/sync/sync_remote.dart';

import '../../support/fake_remote.dart';

final _oidAgen = ObjectId();
final _oidPetani = ObjectId();
final _idLokal = '${_oidAgen.oid}_1730000000000';

TransaksiHiveModel _trx({
  String? idLokal,
  double total = 50000,
  double potongan = 10000,
  String status = 'pending',
  String fotoNota = '',
  String fotoBarang = '',
}) =>
    TransaksiHiveModel(
      idLokal: idLokal ?? _idLokal,
      pengepulId: _oidAgen.oid,
      petaniId: _oidPetani.oid,
      namaPengepul: 'Agen',
      namaPetani: 'Pak Tani',
      namaKomoditas: 'Gabah',
      gradeTerpilih: 'A',
      berat: 10,
      hargaBeliSatuan: total / 10,
      nominalPotongKasbon: potongan,
      totalBayar: total,
      fotoFisikBarang: fotoBarang,
      fotoNota: fotoNota,
      latitude: -6.9,
      longitude: 107.6,
      statusSinkronisasi: status,
      createdAt: DateTime(2026, 1, 1, 8),
    );

void main() {
  final hive = HiveService();
  late Directory dir;
  late FakeRemote remote;
  late SyncEngine engine;
  late Map<String, String?> hasilFoto;
  late List<String> fotoDiunggah;

  SyncEngine buatEngine() => SyncEngine(
        remote: remote,
        hive: hive,
        unggahFoto: (path) async {
          fotoDiunggah.add(path);
          return hasilFoto[path];
        },
        jam: () => DateTime(2026, 2, 1, 9),
      );

  double kasbonCloud() =>
      remote.dokumen('petani').single['sisa_hutang_kasbon'] as double;
  double uangJalanCloud() =>
      remote.dokumen('users').single['sisa_uang_jalan'] as double;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('sync_engine_push');
    await hive.init(testPath: dir.path);
    remote = FakeRemote();
    hasilFoto = {};
    fotoDiunggah = [];
    engine = buatEngine();
    remote.tanam('petani', {
      '_id': _oidPetani,
      'pengepul_id': _oidAgen.oid,
      'saldo_dasar_kasbon': 100000.0,
      'sisa_hutang_kasbon': 100000.0,
    });
    remote.tanam('users', {
      '_id': _oidAgen,
      'role': 'pengepul',
      'saldo_dasar_uang_jalan': 1000000.0,
      'sisa_uang_jalan': 1000000.0,
    });
    await hive.usersBox.put(
      'currentUser',
      UserHiveModel(
        id: _oidAgen.oid,
        username: 'agen',
        passwordHash: '',
        role: 'pengepul',
        sisaUangJalan: 1000000,
        waktuDibuat: DateTime(2026),
      ),
    );
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  group('T1: sinkron dua kali', () {
    test('satu dokumen, saldo berubah sekali, baris synced', () async {
      await hive.transaksiBox.put(_idLokal, _trx());

      final pertama = await engine.siklus();
      await engine.siklus();

      expect(pertama.sukses, isTrue);
      expect(pertama.terkirim, 1);
      expect(remote.dokumen('transaksi'), hasLength(1));
      expect(kasbonCloud(), 90000);
      expect(uangJalanCloud(), 960000);
      final t = hive.transaksiBox.get(_idLokal)!;
      expect(t.statusSinkronisasi, 'synced');
      expect(t.waktuDisinkron, DateTime(2026, 2, 1, 9));
    });

    test('baris yang terkirim ulang tidak memotong saldo lagi', () async {
      final t = _trx();
      await hive.transaksiBox.put(_idLokal, t);
      await engine.siklus();

      t.statusSinkronisasi = 'pending';
      await t.save();
      await engine.siklus();

      expect(remote.dokumen('transaksi'), hasLength(1));
      expect(kasbonCloud(), 90000);
      expect(uangJalanCloud(), 960000);
    });
  });

  group('T2: tulisan sampai, langkah berikutnya gagal, lalu diulang', () {
    test('balasan upsert hilang: tetap pending, lalu satu dokumen', () async {
      await hive.transaksiBox.put(_idLokal, _trx());
      remote.gagalSesudah('updateOne', 1, koleksi: 'transaksi');

      final gagal = await engine.pushTransaksi();

      expect(gagal.terkirim, 0);
      expect(gagal.masalah.single.jenis, 'koneksi_gagal');
      expect(remote.dokumen('transaksi'), hasLength(1));
      expect(hive.transaksiBox.get(_idLokal)!.statusSinkronisasi, 'pending');

      // Aplikasi mati di sini, jadi saldo belum tersentuh.
      expect(kasbonCloud(), 100000);
      expect(uangJalanCloud(), 1000000);

      final ulang = await buatEngine().siklus();

      expect(ulang.sukses, isTrue);
      expect(remote.dokumen('transaksi'), hasLength(1));
      expect(hive.transaksiBox.get(_idLokal)!.statusSinkronisasi, 'synced');
      expect(kasbonCloud(), 90000);
      expect(uangJalanCloud(), 960000);
    });

    test('balasan upsert hilang di tengah siklus: saldo benar di siklus itu juga', () async {
      await hive.transaksiBox.put(_idLokal, _trx());
      remote.gagalSesudah('updateOne', 1, koleksi: 'transaksi');

      final gagal = await engine.siklus();

      expect(gagal.terkirim, 0);
      expect(hive.transaksiBox.get(_idLokal)!.statusSinkronisasi, 'pending');
      expect(kasbonCloud(), 90000);
      expect(uangJalanCloud(), 960000);
      // Baris yang masih pending dan dokumennya tidak boleh terhitung dua kali.
      expect(hive.usersBox.get('currentUser')!.sisaUangJalan, 960000);
    });

    test('tulisan saldo gagal setelah upsert: tercatat, lalu benar pada sync berikutnya', () async {
      await hive.transaksiBox.put(_idLokal, _trx());
      remote.gagalSebelum('updateOne', 1, koleksi: 'petani');

      final hasil = await engine.siklus();

      expect(hasil.masalah.single.jenis, 'saldo_tidak_terbarui');
      expect(hasil.masalah.single.tahap, 'rekonsiliasi');
      expect(hasil.terkirim, 1);
      expect(kasbonCloud(), 100000);
      expect(uangJalanCloud(), 960000);

      final ulang = await buatEngine().siklus();

      expect(ulang.sukses, isTrue);
      expect(kasbonCloud(), 90000);
      expect(uangJalanCloud(), 960000);
      expect(remote.dokumen('transaksi'), hasLength(1));
    });

    test('balasan tulisan saldo hilang: sync berikutnya tidak mengubah apa pun', () async {
      await hive.transaksiBox.put(_idLokal, _trx());
      remote.gagalSesudah('updateOne', 1, koleksi: 'petani');

      await engine.siklus();
      expect(kasbonCloud(), 90000);

      final jumlahTulis = remote.panggilanTulis('petani').length;
      final ulang = await buatEngine().siklus();

      expect(ulang.sukses, isTrue);
      expect(kasbonCloud(), 90000);
      expect(remote.panggilanTulis('petani'), hasLength(jumlahTulis));
    });

    test(r'siklus tidak pernah memakai $inc pada saldo', () async {
      await hive.transaksiBox.put(_idLokal, _trx());
      await hive.transaksiBox.put(
        '${_oidAgen.oid}_2',
        _trx(idLokal: '${_oidAgen.oid}_2', status: 'pending_delete'),
      );

      await engine.siklus();

      final inc = remote.panggilan.where(
        (p) => p.update?.containsKey(r'$inc') ?? false,
      );
      expect(inc, isEmpty);
    });

    test('gagal sebelum diterapkan: tidak ada dokumen, tetap pending', () async {
      await hive.transaksiBox.put(_idLokal, _trx());
      remote.gagalSebelum('updateOne', 1, koleksi: 'transaksi');

      await engine.pushTransaksi();

      expect(remote.dokumen('transaksi'), isEmpty);
      expect(hive.transaksiBox.get(_idLokal)!.statusSinkronisasi, 'pending');
    });
  });

  group('T3: mati setelah upsert, lalu diedit, lalu sync (F7)', () {
    test('edit sampai ke cloud, field tetap tidak berubah', () async {
      final t = _trx();
      await hive.transaksiBox.put(_idLokal, t);
      remote.gagalSesudah('updateOne', 1, koleksi: 'transaksi');
      await engine.pushTransaksi();

      // Mesin baru mewakili aplikasi yang dimulai ulang.
      t
        ..berat = 20
        ..totalBayar = 100000
        ..nominalPotongKasbon = 25000
        ..latitude = 1
        ..createdAt = DateTime(2030);
      await t.save();
      expect(t.statusSinkronisasi, 'pending');
      await buatEngine().pushTransaksi();

      final dok = remote.dokumen('transaksi').single;
      expect(dok['berat'], 20);
      expect(dok['total_bayar'], 100000);
      expect(dok['nominal_potong_kasbon'], 25000);
      expect(dok['latitude'], -6.9);
      expect(dok['created_at'], DateTime(2026, 1, 1, 8).toIso8601String());
      expect(t.statusSinkronisasi, 'synced');
    });

    test('pending_update memakai jalur yang sama dan mengirim potongan', () async {
      final t = _trx(status: 'pending_update', total: 70000, potongan: 30000);
      await hive.transaksiBox.put(_idLokal, t);
      remote.tanam('transaksi', {
        '_id': 'lama',
        'id_lokal': _idLokal,
        'total_bayar': 50000.0,
        'nominal_potong_kasbon': 10000.0,
        'created_at': 'asli',
      });

      final hasil = await engine.pushTransaksi();

      expect(hasil.terkirim, 1);
      final dok = remote.dokumen('transaksi').single;
      expect(dok['total_bayar'], 70000);
      expect(dok['nominal_potong_kasbon'], 30000);
      expect(dok['created_at'], 'asli');
      expect(dok['_id'], 'lama');
      expect(t.statusSinkronisasi, 'synced');
    });
  });

  group('Edit atau hapus selama pengiriman berjalan', () {
    test('edit nilai: tetap pending dan terkirim pada siklus berikutnya', () async {
      final t = _trx();
      await hive.transaksiBox.put(_idLokal, t);
      remote.saatMenungguBalasan = () async {
        t.totalBayar = 80000;
        await t.save();
      };

      await engine.pushTransaksi();

      expect(t.statusSinkronisasi, 'pending');
      expect(remote.dokumen('transaksi').single['total_bayar'], 50000);

      await buatEngine().pushTransaksi();

      expect(t.statusSinkronisasi, 'synced');
      expect(remote.dokumen('transaksi').single['total_bayar'], 80000);
    });

    test('ditandai pending_delete: status tidak tertimpa synced', () async {
      final t = _trx();
      await hive.transaksiBox.put(_idLokal, t);
      remote.saatMenungguBalasan = () async {
        t.statusSinkronisasi = 'pending_delete';
        await t.save();
      };

      await engine.pushTransaksi();

      expect(t.statusSinkronisasi, 'pending_delete');
    });

    test('baris dihapus dari box: tidak melempar', () async {
      final t = _trx();
      await hive.transaksiBox.put(_idLokal, t);
      remote.saatMenungguBalasan = () => hive.transaksiBox.delete(_idLokal);

      final hasil = await engine.pushTransaksi();

      expect(hasil.sukses, isTrue);
    });
  });

  group('Balapan dua upsert (11000)', () {
    test('kalah balapan: diulang sekali tanpa upsert dan menimpa dengan edit', () async {
      remote.buatIndexUnik('transaksi', 'id_lokal');
      remote.balapanUpsert('transaksi', {
        '_id': 'perangkat-lain',
        'id_lokal': _idLokal,
        'total_bayar': 1.0,
      });
      final t = _trx();
      await hive.transaksiBox.put(_idLokal, t);

      final hasil = await engine.pushTransaksi();

      expect(hasil.sukses, isTrue);
      final dok = remote.dokumen('transaksi').single;
      expect(dok['_id'], 'perangkat-lain');
      expect(dok['total_bayar'], 50000);
      expect(t.statusSinkronisasi, 'synced');
      final upsert = remote
          .panggilanTulis('transaksi')
          .map((p) => p.upsert)
          .toList();
      expect(upsert, [true, false]);
    });

    test('kalah balapan: saldo tetap terhitung sekali', () async {
      remote.buatIndexUnik('transaksi', 'id_lokal');
      remote.balapanUpsert('transaksi', {
        'id_lokal': _idLokal,
        'pengepul_id': _oidAgen.oid,
      });
      await hive.transaksiBox.put(_idLokal, _trx());

      await engine.siklus();

      expect(remote.dokumen('transaksi'), hasLength(1));
      expect(kasbonCloud(), 90000);
      expect(uangJalanCloud(), 960000);
    });
  });

  group('Balasan yang menolak', () {
    test('ok false: tetap pending, tercatat dengan kodenya, saldo tidak tersentuh', () async {
      final t = _trx();
      await hive.transaksiBox.put(_idLokal, t);
      remote.tolakBerikutnya('transaksi', 121);

      final hasil = await engine.siklus();

      expect(hasil.terkirim, 0);
      expect(hasil.masalah.single.jenis, 'ditolak_server');
      expect(hasil.masalah.single.pesan, contains('121'));
      expect(t.statusSinkronisasi, 'pending');
      expect(remote.dokumen('transaksi'), isEmpty);
      expect(kasbonCloud(), 100000);
    });

    test('kode 11000 lalu ulangan tidak menemukan dokumen: tetap pending', () async {
      final t = _trx();
      await hive.transaksiBox.put(_idLokal, t);
      remote.tolakBerikutnya('transaksi', RemoteWrite.kodeDuplikat);

      final hasil = await engine.pushTransaksi();

      expect(hasil.masalah.single.jenis, 'dokumen_hilang');
      expect(t.statusSinkronisasi, 'pending');
    });

    test('dokumen saldo tidak ditemukan: SyncIssue, bukan sukses senyap (F3)', () async {
      await hive.transaksiBox.put(
        _idLokal,
        _trx()..petaniId = ObjectId().oid,
      );

      final hasil = await engine.siklus();

      final masalah = hasil.masalah.single;
      expect(masalah.jenis, 'saldo_tidak_terbarui');
      expect(masalah.tahap, 'rekonsiliasi');
      expect(hasil.terkirim, 1);
    });
  });

  group('Baris gagal tidak menghentikan baris lain', () {
    test('baris berikutnya tetap terkirim', () async {
      final kedua = '${_oidAgen.oid}_1730000000001';
      await hive.transaksiBox.put(_idLokal, _trx());
      await hive.transaksiBox.put(kedua, _trx(idLokal: kedua));
      remote.gagalSebelum('updateOne', 1, koleksi: 'transaksi');

      final hasil = await engine.pushTransaksi();

      expect(hasil.terkirim, 1);
      expect(hasil.masalah, hasLength(1));
      expect(remote.dokumen('transaksi'), hasLength(1));
    });
  });

  group('Baris hasil pull dari dokumen tanpa id_lokal', () {
    test('edit mengenai dokumennya lewat _id dan tidak membuat dokumen kedua', () async {
      final oidDok = ObjectId();
      final kunci = oidDok.toString(); // Kunci lama: literal ObjectId("...").
      remote.tanam('transaksi', {'_id': oidDok, 'total_bayar': 1.0});
      final t = _trx(idLokal: kunci, status: 'pending_update');
      await hive.transaksiBox.put(kunci, t);

      final hasil = await engine.pushTransaksi();

      expect(hasil.sukses, isTrue);
      final dok = remote.dokumen('transaksi').single;
      expect(dok['total_bayar'], 50000);
      expect(dok.containsKey('id_lokal'), isFalse);
      expect(t.statusSinkronisasi, 'synced');
    });

    test('dokumennya sudah hilang: SyncIssue, tidak dibuat ulang', () async {
      final kunci = ObjectId().toString();
      final t = _trx(idLokal: kunci, status: 'pending_update');
      await hive.transaksiBox.put(kunci, t);

      final hasil = await engine.pushTransaksi();

      expect(hasil.masalah.single.jenis, 'dokumen_hilang');
      expect(remote.dokumen('transaksi'), isEmpty);
      expect(t.statusSinkronisasi, 'pending_update');
    });
  });

  group('Bentuk dokumen', () {
    test(r'kunci $set dan $setOnInsert saling lepas', () {
      final update = SyncEngine.bangunUpdateTransaksi(_trx(), DateTime(2026));
      final set = (update[r'$set'] as Map).keys.toSet();
      final sisip = (update[r'$setOnInsert'] as Map).keys.toSet();

      expect(set.intersection(sisip), isEmpty);
    });

    test('dokumen baru lengkap dengan id_lokal dari filter, id kanonik', () async {
      final t = _trx()
        ..pengepulId = _oidAgen.toString()
        ..petaniId = _oidPetani.toString();
      await hive.transaksiBox.put(_idLokal, t);

      await engine.pushTransaksi();

      final dok = remote.dokumen('transaksi').single;
      expect(dok['id_lokal'], _idLokal);
      expect(dok['pengepul_id'], _oidAgen.oid);
      expect(dok['petani_id'], _oidPetani.oid);
      expect(dok['nominal_potong_kasbon'], 10000);
      expect(dok['status_sinkronisasi'], 'synced');
      expect(dok['created_at'], DateTime(2026, 1, 1, 8).toIso8601String());
    });

    test('path lokal tidak pernah sampai ke cloud, URL diteruskan', () {
      final update = SyncEngine.bangunUpdateTransaksi(
        _trx(
          fotoNota: '/data/user/0/app/nota.jpg',
          fotoBarang: 'https://res.cloudinary.com/x/barang.jpg',
        ),
        DateTime(2026),
      );
      final set = update[r'$set'] as Map;

      expect(set['foto_nota'], '');
      expect(set['foto_fisik_barang'], 'https://res.cloudinary.com/x/barang.jpg');
    });
  });

  group('Foto pada jalur lama (retry terpisah datang di C13)', () {
    test('unggah berhasil: URL tersimpan di baris dan terkirim', () async {
      final foto = File('${dir.path}/nota.jpg')..writeAsStringSync('x');
      hasilFoto[foto.path] = 'https://cdn/nota.jpg';
      final t = _trx(fotoNota: foto.path);
      await hive.transaksiBox.put(_idLokal, t);

      await engine.pushTransaksi();

      expect(t.fotoNota, 'https://cdn/nota.jpg');
      expect(remote.dokumen('transaksi').single['foto_nota'], 'https://cdn/nota.jpg');
    });

    test('unggah gagal: data uang tetap terkirim tanpa path lokal', () async {
      final foto = File('${dir.path}/nota.jpg')..writeAsStringSync('x');
      final t = _trx(fotoNota: foto.path);
      await hive.transaksiBox.put(_idLokal, t);

      final hasil = await engine.pushTransaksi();

      expect(hasil.terkirim, 1);
      expect(hasil.masalah.single.jenis, 'foto_gagal');
      expect(remote.dokumen('transaksi').single['foto_nota'], '');
      expect(t.statusSinkronisasi, 'synced');
    });

    test('URL tidak diunggah ulang', () async {
      await hive.transaksiBox.put(
        _idLokal,
        _trx(fotoNota: 'https://cdn/lama.jpg'),
      );

      await engine.pushTransaksi();

      expect(fotoDiunggah, isEmpty);
    });
  });

  group('MasterDataService mendelegasikan ke engine', () {
    test('syncAll memakai engine suntikan, tanpa jaringan', () async {
      await hive.transaksiBox.put(_idLokal, _trx());
      final svc = MasterDataService()..engine = engine;

      await svc.syncAll();

      expect(svc.isSyncing, isFalse);
      expect(remote.dokumen('transaksi'), hasLength(1));
      expect(svc.laporanTerakhir?.terkirim, 1);
      expect(hive.transaksiBox.get(_idLokal)!.statusSinkronisasi, 'synced');
    });

    test('offline: laporan mencatatnya dan isSyncing kembali false', () async {
      remote.online = false;
      await hive.transaksiBox.put(_idLokal, _trx());
      final svc = MasterDataService()..engine = engine;

      await svc.syncAll();

      expect(svc.isSyncing, isFalse);
      expect(svc.laporanTerakhir?.masalah.single.jenis, 'offline');
      expect(hive.transaksiBox.get(_idLokal)!.statusSinkronisasi, 'pending');
    });
  });
}
