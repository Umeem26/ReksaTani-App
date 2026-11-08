import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;
import 'package:reksatani_app/models/hive/transaksi_hive_model.dart';
import 'package:reksatani_app/models/hive/user_hive_model.dart';
import 'package:reksatani_app/services/hive_service.dart';
import 'package:reksatani_app/services/sync/sync_engine.dart';

import '../../support/fake_remote.dart';

final _oidAgen = ObjectId();
final _oidPetani = ObjectId();
final _idLokal = '${_oidAgen.oid}_1730000000000';

TransaksiHiveModel _trx({String status = 'pending'}) => TransaksiHiveModel(
      idLokal: _idLokal,
      pengepulId: _oidAgen.oid,
      petaniId: _oidPetani.oid,
      namaPengepul: 'Agen',
      namaPetani: 'Pak Tani',
      namaKomoditas: 'Gabah',
      gradeTerpilih: 'B',
      berat: 10,
      hargaBeliSatuan: 5000,
      nominalPotongKasbon: 0,
      totalBayar: 50000,
      fotoFisikBarang: '',
      fotoNota: '',
      latitude: -6.9,
      longitude: 107.6,
      statusSinkronisasi: status,
      createdAt: DateTime(2026, 1, 1, 8),
    );

TransaksiHiveModel _trxGrading() => _trx()
  ..saranKomoditasAi = 'kopi'
  ..komoditasDiubahPengguna = true
  ..rubrikVersi = 'v0.1-draf'
  ..rubrikJawaban = ['kotoran_hampa=3-10', 'butir=seragam'];

void main() {
  final hive = HiveService();
  late Directory dir;
  late FakeRemote remote;
  late SyncEngine engine;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('sync_engine_grading');
    await hive.init(testPath: dir.path);
    remote = FakeRemote();
    engine = SyncEngine(
      remote: remote,
      hive: hive,
      unggahFoto: (_) async => null,
      jam: () => DateTime(2026, 2, 1, 9),
    );
    remote.tanam('petani', {
      '_id': _oidPetani,
      'pengepul_id': _oidAgen.oid,
      'saldo_dasar_kasbon': 0.0,
      'sisa_hutang_kasbon': 0.0,
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

  group(r'push: field grading masuk $set', () {
    test(r'keempat field ada di $set, bukan $setOnInsert', () {
      final update = SyncEngine.bangunUpdateTransaksi(_trxGrading(), DateTime(2026));
      final set = update[r'$set'] as Map;
      final sisip = update[r'$setOnInsert'] as Map;

      expect(set['saran_komoditas_ai'], 'kopi');
      expect(set['komoditas_diubah_pengguna'], isTrue);
      expect(set['rubrik_versi'], 'v0.1-draf');
      expect(set['rubrik_jawaban'], ['kotoran_hampa=3-10', 'butir=seragam']);
      for (final k in ['saran_komoditas_ai', 'komoditas_diubah_pengguna', 'rubrik_versi', 'rubrik_jawaban']) {
        expect(sisip.containsKey(k), isFalse, reason: k);
      }
    });

    test('baris dengan rubrik_jawaban ditandai synced dan tidak dikirim ulang', () async {
      // Daftar jawaban adalah List: pembanding isi harus menganggapnya sama,
      // atau baris tertahan di antrean selamanya.
      await hive.transaksiBox.put(_idLokal, _trxGrading());

      final pertama = await engine.pushTransaksi();
      final kedua = await engine.pushTransaksi();

      expect(pertama.terkirim, 1);
      expect(kedua.terkirim, 0);
      expect(hive.transaksiBox.get(_idLokal)!.statusSinkronisasi, 'synced');
      final dok = remote.dokumen('transaksi').single;
      expect(dok['grade_terpilih'], 'B');
      expect(dok['rubrik_jawaban'], ['kotoran_hampa=3-10', 'butir=seragam']);
      expect(dok['komoditas_diubah_pengguna'], isTrue);
    });

    test('edit jawaban sesudah terkirim memperbarui dokumen yang sama', () async {
      final t = _trxGrading();
      await hive.transaksiBox.put(_idLokal, t);
      await engine.pushTransaksi();

      t
        ..gradeTerpilih = 'A'
        ..komoditasDiubahPengguna = false
        ..rubrikJawaban = ['kotoran_hampa=sd3', 'butir=seragam']
        ..statusSinkronisasi = 'pending_update';
      await t.save();
      await engine.pushTransaksi();

      final dok = remote.dokumen('transaksi').single;
      expect(dok['grade_terpilih'], 'A');
      expect(dok['komoditas_diubah_pengguna'], isFalse);
      expect(dok['rubrik_jawaban'], ['kotoran_hampa=sd3', 'butir=seragam']);
      expect(t.statusSinkronisasi, 'synced');
    });

    test('baris lama tanpa field grading tetap terkirim: null dan false', () async {
      await hive.transaksiBox.put(_idLokal, _trx());

      final hasil = await engine.pushTransaksi();

      expect(hasil.terkirim, 1);
      final dok = remote.dokumen('transaksi').single;
      expect(dok['saran_komoditas_ai'], isNull);
      expect(dok['komoditas_diubah_pengguna'], isFalse);
      expect(dok['rubrik_versi'], isNull);
      expect(dok['rubrik_jawaban'], isNull);
      expect(hive.transaksiBox.get(_idLokal)!.statusSinkronisasi, 'synced');
    });
  });

  group('pull', () {
    Map<String, dynamic> dok(String idLokal) => {
          '_id': ObjectId(),
          'id_lokal': idLokal,
          'pengepul_id': _oidAgen.oid,
          'petani_id': _oidPetani.oid,
          'nama_pengepul': 'Agen',
          'nama_petani': 'Pak Tani',
          'nama_komoditas': 'Sawit',
          'grade_terpilih': 'C',
          'berat': 10.0,
          'harga_beli_satuan': 2000.0,
          'nominal_potong_kasbon': 0.0,
          'total_bayar': 20000.0,
          'status_sinkronisasi': 'synced',
          'created_at': DateTime(2026, 1, 2).toIso8601String(),
        };

    test('dokumen dengan field grading dibaca ke baris lokal', () async {
      final id = '${_oidAgen.oid}_1730000000001';
      remote.tanam('transaksi', {
        ...dok(id),
        'saran_komoditas_ai': 'kelapa_sawit',
        'komoditas_diubah_pengguna': false,
        'rubrik_versi': 'v0.1-draf',
        'rubrik_jawaban': ['brondolan=nol', 'buah_dalam=tidak'],
      });

      await engine.siklus();

      final t = hive.transaksiBox.get(id)!;
      expect(t.saranKomoditasAi, 'kelapa_sawit');
      expect(t.komoditasDiubahPengguna, isFalse);
      expect(t.rubrikVersi, 'v0.1-draf');
      expect(t.rubrikJawaban, ['brondolan=nol', 'buah_dalam=tidak']);
    });

    test('dokumen lama tanpa field grading dibaca sebagai null dan false', () async {
      final id = '${_oidAgen.oid}_1730000000002';
      remote.tanam('transaksi', dok(id));

      await engine.siklus();

      final t = hive.transaksiBox.get(id)!;
      expect(t.gradeTerpilih, 'C');
      expect(t.saranKomoditasAi, isNull);
      expect(t.komoditasDiubahPengguna, isFalse);
      expect(t.rubrikVersi, isNull);
      expect(t.rubrikJawaban, isNull);
    });
  });
}
