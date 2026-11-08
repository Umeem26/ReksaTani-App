import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;
import 'package:reksatani_app/models/hive/komoditas_hive_model.dart';
import 'package:reksatani_app/models/hive/petani_hive_model.dart';
import 'package:reksatani_app/models/hive/transaksi_hive_model.dart';
import 'package:reksatani_app/models/hive/user_hive_model.dart';
import 'package:reksatani_app/services/hive_service.dart';
import 'package:reksatani_app/services/sync/sync_engine.dart';

import '../../support/fake_remote.dart';

final _oidAgen = ObjectId();
final _oidPetani = ObjectId();
final _idLokal = '${_oidAgen.oid}_1730000000000';

TransaksiHiveModel _trx({
  String? idLokal,
  String? petaniId,
  String komoditas = 'Gabah',
  double total = 50000,
  double potongan = 10000,
  String status = 'pending',
}) =>
    TransaksiHiveModel(
      idLokal: idLokal ?? _idLokal,
      pengepulId: _oidAgen.oid,
      petaniId: petaniId ?? _oidPetani.oid,
      namaPengepul: 'Agen',
      namaPetani: 'Pak Tani',
      namaKomoditas: komoditas,
      gradeTerpilih: 'A',
      berat: 10,
      hargaBeliSatuan: total / 10,
      nominalPotongKasbon: potongan,
      totalBayar: total,
      fotoFisikBarang: '',
      fotoNota: '',
      latitude: 0,
      longitude: 0,
      statusSinkronisasi: status,
      createdAt: DateTime(2026, 1, 1, 8),
    );

Map<String, dynamic> _dokTrx(
  String idLokal, {
  Object? petani,
  Object? agen,
  String komoditas = 'Gabah',
  double total = 50000,
  double potongan = 10000,
}) =>
    {
      'id_lokal': idLokal,
      'petani_id': petani ?? _oidPetani.oid,
      'pengepul_id': agen ?? _oidAgen.oid,
      'nama_komoditas': komoditas,
      'total_bayar': total,
      'nominal_potong_kasbon': potongan,
      'status_sinkronisasi': 'synced',
      'created_at': '2026-01-01T08:00:00.000',
    };

void main() {
  final hive = HiveService();
  late Directory dir;
  late FakeRemote remote;
  late SyncEngine engine;

  SyncEngine buatEngine() => SyncEngine(
        remote: remote,
        hive: hive,
        unggahFoto: (_) async => null,
        jam: () => DateTime(2026, 2, 1, 9),
      );

  Map<String, dynamic> dokPetani() => remote.dokumen('petani').firstWhere(
        (d) => d['_id'] == _oidPetani,
      );
  Map<String, dynamic> dokAgen() =>
      remote.dokumen('users').firstWhere((d) => d['_id'] == _oidAgen);
  double kasbonCloud() => dokPetani()['sisa_hutang_kasbon'] as double;
  double uangJalanCloud() => dokAgen()['sisa_uang_jalan'] as double;

  PetaniHiveModel petaniLokal() => hive.petaniBox.get(_oidPetani.oid)!;
  UserHiveModel userLokal() => hive.usersBox.get('currentUser')!;

  Future<void> pasangUser({String role = 'pengepul', double uangJalan = 1000000}) =>
      hive.usersBox.put(
        'currentUser',
        UserHiveModel(
          id: _oidAgen.oid,
          username: 'agen',
          passwordHash: 'hash-lokal',
          role: role,
          sisaUangJalan: uangJalan,
          waktuDibuat: DateTime(2026),
        ),
      );

  void topUp(Object id, double nominal) {
    remote.updateOne('users', {'_id': id}, {
      r'$inc': {'saldo_dasar_uang_jalan': nominal, 'sisa_uang_jalan': nominal},
    });
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('sync_engine_saldo');
    await hive.init(testPath: dir.path);
    remote = FakeRemote();
    engine = buatEngine();
    remote.tanam('petani', {
      '_id': _oidPetani,
      'nama_petani': 'Pak Tani',
      'desa': 'Sukamaju',
      'pengepul_id': _oidAgen.oid,
      'saldo_dasar_kasbon': 100000.0,
      'sisa_hutang_kasbon': 100000.0,
    });
    remote.tanam('users', {
      '_id': _oidAgen,
      'username': 'agen',
      'role': 'pengepul',
      'saldo_dasar_uang_jalan': 1000000.0,
      'sisa_uang_jalan': 1000000.0,
    });
    await pasangUser();
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  group('T9: pencairan kasbon', () {
    test('kasbon cloud bertambah dan kas berkurang, sync berikut tidak menghilangkan', () async {
      await hive.transaksiBox.put(
        _idLokal,
        _trx(komoditas: 'Pencairan Kasbon Baru', total: 25000, potongan: 0),
      );

      await engine.siklus();
      expect(kasbonCloud(), 125000);
      expect(uangJalanCloud(), 975000);

      await engine.siklus();
      expect(kasbonCloud(), 125000);
      expect(uangJalanCloud(), 975000);
      expect(petaniLokal().sisaHutangKasbon, 125000);
      expect(userLokal().sisaUangJalan, 975000);
    });
  });

  group('T12: bentuk id', () {
    Future<void> uji({
      required Object idPetani,
      required Object refPetani,
      required Object idAgen,
      required Object refAgen,
    }) async {
      final kunciUser = idAgen is ObjectId ? idAgen.oid : idAgen.toString();
      remote.tanam('petani', {
        '_id': idPetani,
        'pengepul_id': refAgen,
        'saldo_dasar_kasbon': 500.0,
        'sisa_hutang_kasbon': 500.0,
      });
      remote.tanam('users', {
        '_id': idAgen,
        'role': 'pengepul',
        'saldo_dasar_uang_jalan': 900.0,
        'sisa_uang_jalan': 900.0,
      });
      remote.tanam(
        'transaksi',
        _dokTrx('x_1', petani: refPetani, agen: refAgen, total: 300, potongan: 100),
      );
      await hive.usersBox.put(
        'currentUser',
        UserHiveModel(
          id: kunciUser,
          username: 'a',
          passwordHash: '',
          role: 'pengepul',
          sisaUangJalan: 0,
          waktuDibuat: DateTime(2026),
        ),
      );

      final laporan = await engine.siklus();

      expect(laporan.sukses, isTrue, reason: '${laporan.masalah}');
      final p = remote.dokumen('petani').firstWhere((d) => d['_id'] == idPetani);
      final u = remote.dokumen('users').firstWhere((d) => d['_id'] == idAgen);
      expect(p['sisa_hutang_kasbon'], 400);
      expect(u['sisa_uang_jalan'], 700);
      expect(hive.usersBox.get('currentUser')!.sisaUangJalan, 700);
    }

    test('_id ObjectId, referensi hex', () {
      final p = ObjectId();
      final a = ObjectId();
      return uji(idPetani: p, refPetani: p.oid, idAgen: a, refAgen: a.oid);
    });

    test('_id ObjectId, referensi literal lama', () {
      final p = ObjectId();
      final a = ObjectId();
      return uji(
        idPetani: p,
        refPetani: 'ObjectId("${p.oid}")',
        idAgen: a,
        refAgen: 'ObjectId("${a.oid}")',
      );
    });

    test('_id ObjectId, referensi ObjectId', () {
      final p = ObjectId();
      final a = ObjectId();
      return uji(idPetani: p, refPetani: p, idAgen: a, refAgen: a);
    });

    test('_id string UUID', () => uji(
          idPetani: 'petani-uuid-1',
          refPetani: 'petani-uuid-1',
          idAgen: 'agen-uuid-1',
          refAgen: 'agen-uuid-1',
        ));

    test('transaksi merujuk petani yang tidak ada: SyncIssue, saldo agen tetap benar', () async {
      remote.tanam('transaksi', _dokTrx('x_1', petani: ObjectId().oid));

      final laporan = await engine.siklus();

      expect(laporan.masalah.single.jenis, 'saldo_tidak_terbarui');
      expect(laporan.masalah.single.pesan, contains('tidak ditemukan'));
      expect(uangJalanCloud(), 960000);
    });

    test('dokumen agen tidak ada: SyncIssue', () async {
      await pasangUser();
      hive.usersBox.get('currentUser')!.id = ObjectId().oid;

      final laporan = await engine.siklus();

      expect(
        laporan.masalah.map((m) => m.pesan),
        contains(contains('users/')),
      );
    });

    test('dokumen hilang di antara baca dan tulis (matched 0): SyncIssue', () async {
      remote.tanam('transaksi', _dokTrx('x_1'));
      remote.saatMenungguBalasan = () async {
        await remote.deleteOne('users', {'_id': _oidAgen});
      };

      final laporan = await engine.siklus();

      expect(laporan.masalah.single.jenis, 'saldo_tidak_terbarui');
      expect(laporan.masalah.single.pesan, contains('users/'));
    });
  });

  group('T13: duplikat di data lama', () {
    test('saldo menghitung sekali', () async {
      remote.tanam('transaksi', _dokTrx('x_1'));
      remote.tanam('transaksi', _dokTrx('x_1'));

      await engine.siklus();

      expect(remote.dokumen('transaksi'), hasLength(2));
      expect(kasbonCloud(), 90000);
      expect(uangJalanCloud(), 960000);
    });
  });

  group('T14: dokumen tanpa saldo dasar', () {
    setUp(() {
      remote = FakeRemote();
      engine = buatEngine();
      remote.tanam('petani', {
        '_id': _oidPetani,
        'pengepul_id': _oidAgen.oid,
        'sisa_hutang_kasbon': 100000.0,
      });
      remote.tanam('users', {
        '_id': _oidAgen,
        'role': 'pengepul',
        'sisa_uang_jalan': 1000000.0,
      });
    });

    test('sisa tidak ditimpa dan tercatat', () async {
      await hive.transaksiBox.put(_idLokal, _trx());

      final laporan = await engine.siklus();

      expect(kasbonCloud(), 100000);
      expect(uangJalanCloud(), 1000000);
      expect(remote.panggilanTulis('petani'), isEmpty);
      expect(remote.panggilanTulis('users'), isEmpty);
      expect(
        laporan.masalah.map((m) => m.jenis),
        ['belum_dimigrasi', 'belum_dimigrasi'],
      );
    });

    test('saldo lokal dipertahankan, karena nilai cloud tidak mengikuti transaksi', () async {
      await hive.petaniBox.put(
        _oidPetani.oid,
        PetaniHiveModel(
          id: _oidPetani.oid,
          namaPetani: 'Pak Tani',
          desa: '',
          pengepulId: _oidAgen.oid,
          sisaHutangKasbon: 90000,
          waktuDibuat: DateTime(2026),
        ),
      );
      await pasangUser(uangJalan: 960000);
      await hive.transaksiBox.put(_idLokal, _trx());

      await engine.siklus();

      expect(petaniLokal().sisaHutangKasbon, 90000);
      expect(userLokal().sisaUangJalan, 960000);
    });
  });

  group('T16: saldo lokal mengikuti cloud (F6)', () {
    test('tambahan dari manajer sampai ke HP', () async {
      await engine.siklus();
      topUp(_oidAgen, 500000);

      await engine.siklus();

      expect(uangJalanCloud(), 1500000);
      expect(userLokal().sisaUangJalan, 1500000);
    });

    test('tambahan dari manajer, dengan transaksi tertunda tetap terhitung', () async {
      topUp(_oidAgen, 500000);
      await hive.transaksiBox.put(_idLokal, _trx());
      remote.gagalSebelum('updateOne', 1, koleksi: 'transaksi');

      await engine.siklus();

      expect(hive.transaksiBox.get(_idLokal)!.statusSinkronisasi, 'pending');
      expect(uangJalanCloud(), 1500000);
      expect(userLokal().sisaUangJalan, 1460000);
      expect(petaniLokal().sisaHutangKasbon, 90000);
    });

    test('pending_update yang belum terkirim memakai nilai baris', () async {
      remote.tanam('transaksi', _dokTrx(_idLokal));
      await hive.transaksiBox.put(
        _idLokal,
        _trx(total: 80000, potongan: 20000, status: 'pending_update'),
      );
      remote.gagalSebelum('updateOne', 1, koleksi: 'transaksi');

      await engine.siklus();

      expect(kasbonCloud(), 90000);
      expect(petaniLokal().sisaHutangKasbon, 80000);
      expect(userLokal().sisaUangJalan, 940000);
    });

    test('pending_delete yang belum terkirim sudah dikembalikan di lokal', () async {
      remote.tanam('transaksi', _dokTrx(_idLokal));
      await hive.transaksiBox.put(_idLokal, _trx(status: 'pending_delete'));
      remote.gagalSebelum('deleteOne', 1);

      await engine.siklus();

      expect(kasbonCloud(), 90000);
      expect(petaniLokal().sisaHutangKasbon, 100000);
      expect(userLokal().sisaUangJalan, 1000000);
    });

    test('transaksi milik agen lain di perangkat ini tidak mengurangi kas sendiri', () async {
      final lain = ObjectId().oid;
      await hive.transaksiBox.put(
        'x_9',
        _trx(idLokal: 'x_9', potongan: 0)..pengepulId = lain,
      );
      remote.gagalSebelum('updateOne', 1, koleksi: 'transaksi');

      await engine.siklus();

      expect(userLokal().sisaUangJalan, 1000000);
    });
  });

  group('Petani bersama', () {
    test('kasbon memuat transaksi agen lain, uang jalan hanya milik sendiri', () async {
      final agenLain = ObjectId().oid;
      remote.tanam(
        'transaksi',
        _dokTrx('lain_1', agen: agenLain, total: 30000, potongan: 30000),
      );
      await hive.transaksiBox.put(_idLokal, _trx());

      await engine.siklus();

      expect(kasbonCloud(), 60000);
      expect(petaniLokal().sisaHutangKasbon, 60000);
      expect(uangJalanCloud(), 960000);
    });

    test('petani milik agen lain yang dirujuk transaksi ikut direkonsiliasi', () async {
      final oidLuar = ObjectId();
      remote.tanam('petani', {
        '_id': oidLuar,
        'pengepul_id': 'agen-lain',
        'saldo_dasar_kasbon': 70000.0,
        'sisa_hutang_kasbon': 70000.0,
      });
      await hive.transaksiBox.put(_idLokal, _trx(petaniId: oidLuar.oid));

      await engine.siklus();

      final luar =
          remote.dokumen('petani').firstWhere((d) => d['_id'] == oidLuar);
      expect(luar['sisa_hutang_kasbon'], 60000);
      expect(hive.petaniBox.get(oidLuar.oid)!.sisaHutangKasbon, 60000);
    });

    test('petani yang tidak ada kaitannya tidak ditulis, lokal mengikuti cloud', () async {
      final oidLuar = ObjectId();
      remote.tanam('petani', {
        '_id': oidLuar,
        'pengepul_id': 'agen-lain',
        'saldo_dasar_kasbon': 70000.0,
        'sisa_hutang_kasbon': 55000.0,
      });

      await engine.siklus();

      expect(remote.panggilanTulis('petani'), isEmpty);
      expect(hive.petaniBox.get(oidLuar.oid)!.sisaHutangKasbon, 55000);
    });

    test('kasbon jadi negatif: tidak di-clamp dan tercatat', () async {
      remote.tanam('transaksi', _dokTrx('x_1', total: 150000, potongan: 150000));

      final laporan = await engine.siklus();

      expect(kasbonCloud(), -50000);
      expect(laporan.masalah.single.jenis, 'kasbon_negatif');
    });
  });

  group('Tulisan saldo', () {
    test('sinkron dua kali tidak menulis apa pun lagi', () async {
      await hive.transaksiBox.put(_idLokal, _trx());
      await engine.siklus();

      final sebelum = remote.panggilan.where((p) => p.update != null).length;
      final isi = [
        remote.dokumen('petani'),
        remote.dokumen('users'),
        remote.dokumen('transaksi'),
      ];

      final laporan = await engine.siklus();

      expect(laporan.sukses, isTrue);
      expect(remote.panggilan.where((p) => p.update != null), hasLength(sebelum));
      expect(remote.dokumen('petani'), isi[0]);
      expect(remote.dokumen('users'), isi[1]);
      expect(remote.dokumen('transaksi'), isi[2]);
    });

    test('selisih di bawah toleransi tidak ditulis', () async {
      remote = FakeRemote();
      engine = buatEngine();
      remote.tanam('petani', {
        '_id': _oidPetani,
        'pengepul_id': _oidAgen.oid,
        'saldo_dasar_kasbon': 100.0,
        'sisa_hutang_kasbon': 100.005,
      });
      remote.tanam('users', {
        '_id': _oidAgen,
        'role': 'pengepul',
        'saldo_dasar_uang_jalan': 100.0,
        'sisa_uang_jalan': 100.0,
      });

      await engine.siklus();

      expect(remote.panggilanTulis('petani'), isEmpty);
    });

    test('top-up manajer yang masuk sesudah pembacaan tidak tertimpa', () async {
      remote.tanam('transaksi', _dokTrx('x_1'));
      // Fake menjalankan ini tepat setelah tulisan pertama, yaitu saldo petani.
      // Dokumen agen sudah terbaca dengan saldo dasar lama.
      remote.saatMenungguBalasan = () async => topUp(_oidAgen, 500000);

      final laporan = await engine.siklus();

      expect(laporan.masalah.single.jenis, 'saldo_tidak_terbarui');
      expect(uangJalanCloud(), 1500000);

      final ulang = await engine.siklus();

      expect(ulang.sukses, isTrue);
      expect(uangJalanCloud(), 1460000);
      expect(userLokal().sisaUangJalan, 1460000);
    });
  });

  group('Kegagalan baca', () {
    test('rekonsiliasi gagal: tidak ada tulisan saldo dan saldo lokal dipertahankan', () async {
      await hive.transaksiBox.put(_idLokal, _trx());
      await pasangUser(uangJalan: 960000);
      await hive.petaniBox.put(
        _oidPetani.oid,
        PetaniHiveModel(
          id: _oidPetani.oid,
          namaPetani: 'Pak Tani',
          desa: '',
          pengepulId: _oidAgen.oid,
          sisaHutangKasbon: 90000,
          waktuDibuat: DateTime(2026),
        ),
      );
      remote.gagalSebelum('find', 1, koleksi: 'transaksi');

      final laporan = await engine.siklus();

      expect(laporan.masalah.single.tahap, 'rekonsiliasi');
      expect(laporan.masalah.single.jenis, 'koneksi_gagal');
      expect(remote.panggilanTulis('petani'), isEmpty);
      expect(remote.panggilanTulis('users'), isEmpty);
      expect(petaniLokal().sisaHutangKasbon, 90000);
      expect(userLokal().sisaUangJalan, 960000);

      final ulang = await engine.siklus();
      expect(ulang.sukses, isTrue);
      expect(kasbonCloud(), 90000);
    });

    test('pull satu koleksi gagal: tercatat, data lokal utuh, tahap lain tetap jalan', () async {
      await hive.petaniBox.put(
        _oidPetani.oid,
        PetaniHiveModel(
          id: _oidPetani.oid,
          namaPetani: 'Nama Lokal',
          desa: '',
          pengepulId: _oidAgen.oid,
          sisaHutangKasbon: 1,
          waktuDibuat: DateTime(2026),
        ),
      );
      remote.tanam('transaksi', _dokTrx('x_1'));
      // Pembacaan pertama dan kedua milik rekonsiliasi.
      remote.gagalSebelum('find', 1, koleksi: 'petani', lewati: 1);

      final laporan = await engine.siklus();

      expect(laporan.masalah.single.tahap, 'pull_petani');
      expect(petaniLokal().namaPetani, 'Nama Lokal');
      expect(hive.transaksiBox.containsKey('x_1'), isTrue);
    });

    test('pull komoditas gagal: daftar lokal tidak dikosongkan', () async {
      await hive.komoditasBox.put(
        'k1',
        KomoditasHiveModel(
          id: 'k1',
          namaKomoditas: 'Gabah',
          unitSatuan: 'kg',
          gradeKualitas: const [],
          diperbaruiOleh: '',
          waktuPembaruan: DateTime(2026),
        ),
      );
      remote.gagalSebelum('find', 1, koleksi: 'komoditas');

      final laporan = await engine.siklus();

      expect(laporan.masalah.single.tahap, 'pull_komoditas');
      expect(hive.komoditasBox.containsKey('k1'), isTrue);
    });

    test('pull agen gagal: baris lama dan currentUser tetap ada', () async {
      remote.gagalSebelum('find', 1, koleksi: 'users', lewati: 1);
      await hive.usersBox.put(
        'agen-lain',
        UserHiveModel(
          id: 'agen-lain',
          username: 'lain',
          passwordHash: '',
          role: 'pengepul',
          sisaUangJalan: 0,
          waktuDibuat: DateTime(2026),
        ),
      );

      final laporan = await engine.siklus();

      expect(laporan.masalah.single.tahap, 'pull_agen');
      expect(hive.usersBox.containsKey('agen-lain'), isTrue);
      expect(hive.usersBox.containsKey('currentUser'), isTrue);
    });

    test('pull riwayat gagal: tercatat', () async {
      remote.gagalSebelum('find', 1, koleksi: 'transaksi', lewati: 2);

      final laporan = await engine.siklus();

      expect(laporan.masalah.single.tahap, 'pull_riwayat');
    });
  });

  group('Pull lewat SyncRemote (U17)', () {
    test('petani: objek yang dipegang layar tetap bisa disimpan setelah sync (F8)', () async {
      final dipegang = PetaniHiveModel(
        id: _oidPetani.oid,
        namaPetani: 'Lama',
        desa: 'Lama',
        pengepulId: _oidAgen.oid,
        sisaHutangKasbon: 5,
        waktuDibuat: DateTime(2026),
      );
      await hive.petaniBox.put(dipegang.id, dipegang);

      await engine.siklus();

      expect(identical(hive.petaniBox.get(dipegang.id), dipegang), isTrue);
      expect(dipegang.namaPetani, 'Pak Tani');
      expect(dipegang.sisaHutangKasbon, 100000);
      await dipegang.save();
    });

    test('petani: id kanonik, waktu dari waktu_dibuat atau created_at', () async {
      final dua = ObjectId();
      remote.tanam('petani', {
        '_id': dua,
        'nama_petani': 'Kedua',
        'desa': 'Desa',
        'pengepul_id': 'ObjectId("${_oidAgen.oid}")',
        'saldo_dasar_kasbon': 0,
        'sisa_hutang_kasbon': 0,
        'created_at': '2025-03-04T05:06:07.000',
      });

      await engine.siklus();

      final m = hive.petaniBox.get(dua.oid)!;
      expect(m.id, dua.oid);
      expect(m.pengepulId, _oidAgen.oid);
      expect(m.namaPetani, 'Kedua');
      expect(m.waktuDibuat, DateTime(2025, 3, 4, 5, 6, 7));
    });

    test('agen: baris lain diganti, currentUser tidak terhapus dan sandinya utuh', () async {
      await hive.usersBox.put(
        'agen-lama',
        UserHiveModel(
          id: 'agen-lama',
          username: 'lama',
          passwordHash: '',
          role: 'pengepul',
          sisaUangJalan: 0,
          waktuDibuat: DateTime(2026),
        ),
      );
      final baru = ObjectId();
      remote.tanam('users', {
        '_id': baru,
        'username': 'baru',
        'role': 'pengepul',
        'sisa_uang_jalan': 7000,
      });
      remote.tanam('users', {'_id': ObjectId(), 'role': 'manajer'});

      await engine.siklus();

      expect(hive.usersBox.containsKey('agen-lama'), isFalse);
      expect(hive.usersBox.get(baru.oid)!.username, 'baru');
      expect(hive.usersBox.get(baru.oid)!.sisaUangJalan, 7000);
      expect(hive.usersBox.values.where((u) => u.role == 'manajer'), isEmpty);
      expect(userLokal().passwordHash, 'hash-lokal');
    });

    test('riwayat: dokumen baru masuk dengan kunci yang benar dan terhitung', () async {
      final oidTanpaIdLokal = ObjectId();
      remote.tanam('transaksi', {
        '_id': oidTanpaIdLokal,
        'pengepul_id': 'ObjectId("${_oidAgen.oid}")',
        'petani_id': _oidPetani,
        'nama_komoditas': 'Sawit',
        'berat': 3,
        'total_bayar': 9000,
      });
      remote.tanam('transaksi', _dokTrx('x_1'));
      remote.tanam('transaksi', _dokTrx('agen_lain_1', agen: 'agen-lain'));

      final laporan = await engine.siklus();
      final kedua = await engine.siklus();

      expect(laporan.riwayatBaru, 2);
      expect(kedua.riwayatBaru, 0);
      expect(hive.transaksiBox.containsKey('agen_lain_1'), isFalse);

      final m = hive.transaksiBox.get(oidTanpaIdLokal.toString())!;
      expect(m.pengepulId, _oidAgen.oid);
      expect(m.petaniId, _oidPetani.oid);
      expect(m.berat, 3);
      expect(m.totalBayar, 9000);
      expect(m.statusSinkronisasi, 'synced');
      expect(hive.transaksiBox.get('x_1')!.createdAt, DateTime(2026, 1, 1, 8));
    });

    test('riwayat: baris lokal tidak tertimpa dokumen cloud', () async {
      remote.tanam('transaksi', _dokTrx(_idLokal, total: 1));
      await hive.transaksiBox.put(
        _idLokal,
        _trx(total: 99999, status: 'synced'),
      );

      final laporan = await engine.siklus();

      expect(laporan.riwayatBaru, 0);
      expect(hive.transaksiBox.get(_idLokal)!.totalBayar, 99999);
    });

    test('komoditas: grade dan harga masuk', () async {
      remote.tanam('komoditas', {
        '_id': 'k1',
        'nama_komoditas': 'Gabah',
        'grade_kualitas': [
          {'grade': 'A', 'harga_maks': 7500},
        ],
      });

      await engine.siklus();

      final k = hive.komoditasBox.get('k1')!;
      expect(k.unitSatuan, 'kg');
      expect(k.gradeKualitas.single['harga_maks'], 7500.0);
    });
  });

  group('Peran manajer', () {
    setUp(() => pasangUser(role: 'manajer', uangJalan: 0));

    test('tidak menulis saldo, lokal mengikuti nilai cloud, riwayat semua agen', () async {
      remote.tanam('transaksi', _dokTrx('x_1'));
      remote.tanam('transaksi', _dokTrx('y_1', agen: 'agen-lain'));

      final laporan = await engine.siklus();

      expect(laporan.sukses, isTrue);
      expect(laporan.riwayatBaru, 2);
      expect(remote.panggilanTulis('petani'), isEmpty);
      expect(remote.panggilanTulis('users'), isEmpty);
      expect(petaniLokal().sisaHutangKasbon, 100000);
      expect(userLokal().sisaUangJalan, 0);
    });

    test('nilai petani lokal yang lama diganti nilai cloud', () async {
      await hive.petaniBox.put(
        _oidPetani.oid,
        PetaniHiveModel(
          id: _oidPetani.oid,
          namaPetani: 'x',
          desa: '',
          pengepulId: '',
          sisaHutangKasbon: 1,
          waktuDibuat: DateTime(2026),
        ),
      );

      await engine.siklus();

      expect(petaniLokal().sisaHutangKasbon, 100000);
    });
  });
}
