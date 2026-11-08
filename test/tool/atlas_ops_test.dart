import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;
import 'package:reksatani_app/models/hive/user_hive_model.dart';
import 'package:reksatani_app/services/hive_service.dart';
import 'package:reksatani_app/services/sync/sync_engine.dart';

import '../../tool/atlas/atlas_ops.dart';
import '../support/fake_remote.dart';

void main() {
  late FakeRemote remote;
  late List<String> keluaran;
  final oidPetani = ObjectId();
  final oidAgen = ObjectId();

  int jumlahTulis() => remote.panggilan
      .where((p) => p.update != null || p.op == 'deleteOne')
      .length;

  setUp(() {
    remote = FakeRemote();
    keluaran = [];
    remote.tanam('transaksi', {'id_lokal': 'a_1', 'total_bayar': 1.0});
    remote.tanam('transaksi', {'_id': 'uuid-trx', 'total_bayar': 1.0});
    remote.tanam('petani', {
      '_id': oidPetani,
      'sisa_hutang_kasbon': 70000.0,
    });
    remote.tanam('petani', {
      '_id': 'uuid-petani',
      'saldo_dasar_kasbon': 50000.0,
      'sisa_hutang_kasbon': 20000.0,
    });
    remote.tanam('users', {
      '_id': oidAgen,
      'role': 'pengepul',
      'sisa_uang_jalan': 900.0,
    });
    remote.tanam('users', {
      '_id': 'manajer-1',
      'role': 'manajer',
      'sisa_uang_jalan': 5.0,
    });
  });

  Map<String, dynamic> dok(String koleksi, Object id) =>
      remote.dokumen(koleksi).firstWhere((d) => d['_id'] == id);

  group('OpsiCli', () {
    test('default tidak menulis', () {
      expect(OpsiCli.parse(const []).konfirmasi, isFalse);
      expect(const OpsiCli().konfirmasi, isFalse);
    });

    test('--confirm dan nilai terbaca', () {
      final o = OpsiCli.parse(
        const ['--confirm', '--kasbon=0', '--uang-jalan=250000'],
        izinkanNilai: true,
      );

      expect(o.konfirmasi, isTrue);
      expect(o.kasbon, 0);
      expect(o.uangJalan, 250000);
    });

    test('salah ketik ditolak, bukan dianggap perintah', () {
      expect(() => OpsiCli.parse(const ['--confirmm']), throwsFormatException);
      expect(() => OpsiCli.parse(const ['--force']), throwsFormatException);
    });

    test('nilai hanya diterima skrip yang memakainya', () {
      expect(() => OpsiCli.parse(const ['--kasbon=1']), throwsFormatException);
    });

    test('nilai tidak sah ditolak', () {
      expect(
        () => OpsiCli.parse(const ['--kasbon=abc'], izinkanNilai: true),
        throwsFormatException,
      );
      expect(
        () => OpsiCli.parse(const ['--uang-jalan=-5'], izinkanNilai: true),
        throwsFormatException,
      );
    });
  });

  group('resetDataUji', () {
    test('tanpa --confirm: tidak menulis apa pun dan melaporkan jumlahnya', () async {
      await resetDataUji(remote, const OpsiCli(), cetak: keluaran.add);

      expect(jumlahTulis(), 0);
      expect(remote.dokumen('transaksi'), hasLength(2));
      expect(keluaran.join('\n'), contains('DRY-RUN'));
      expect(keluaran.join('\n'), contains('dihapus : 2'));
    });

    test('dengan --confirm: transaksi habis, sisa sama dengan dasar', () async {
      await resetDataUji(
        remote,
        const OpsiCli(konfirmasi: true),
        cetak: keluaran.add,
      );

      expect(remote.dokumen('transaksi'), isEmpty);
      final baru = dok('petani', oidPetani);
      expect(baru['saldo_dasar_kasbon'], 70000);
      expect(baru['sisa_hutang_kasbon'], 70000);
      final lama = dok('petani', 'uuid-petani');
      expect(lama['saldo_dasar_kasbon'], 50000);
      expect(lama['sisa_hutang_kasbon'], 50000);
      final agen = dok('users', oidAgen);
      expect(agen['saldo_dasar_uang_jalan'], 900);
      expect(agen['sisa_uang_jalan'], 900);
    });

    test('nilai eksplisit menang', () async {
      await resetDataUji(
        remote,
        const OpsiCli(konfirmasi: true, kasbon: 0, uangJalan: 250000),
        cetak: keluaran.add,
      );

      expect(dok('petani', oidPetani)['saldo_dasar_kasbon'], 0);
      expect(dok('petani', 'uuid-petani')['sisa_hutang_kasbon'], 0);
      expect(dok('users', oidAgen)['sisa_uang_jalan'], 250000);
    });

    test('akun manajer, petani, dan komoditas tidak terhapus atau berubah', () async {
      remote.tanam('komoditas', {'_id': 'k1'});

      await resetDataUji(
        remote,
        const OpsiCli(konfirmasi: true, uangJalan: 1),
        cetak: keluaran.add,
      );

      final manajer = dok('users', 'manajer-1');
      expect(manajer['sisa_uang_jalan'], 5);
      expect(manajer.containsKey('saldo_dasar_uang_jalan'), isFalse);
      expect(remote.dokumen('petani'), hasLength(2));
      expect(remote.dokumen('komoditas'), hasLength(1));
    });

    test('terhenti di tengah lalu diulang: hasilnya sama', () async {
      remote.gagalSebelum('updateOne', 1, koleksi: 'users');

      await expectLater(
        resetDataUji(
          remote,
          const OpsiCli(konfirmasi: true),
          cetak: keluaran.add,
        ),
        throwsA(isA<RemoteGagal>()),
      );
      await resetDataUji(
        remote,
        const OpsiCli(konfirmasi: true),
        cetak: keluaran.add,
      );

      expect(remote.dokumen('transaksi'), isEmpty);
      expect(dok('users', oidAgen)['saldo_dasar_uang_jalan'], 900);
    });

    test('penulisan yang ditolak dilaporkan sebagai kegagalan', () async {
      remote.tolakBerikutnya('petani', 13);

      await expectLater(
        resetDataUji(
          remote,
          const OpsiCli(konfirmasi: true),
          cetak: keluaran.add,
        ),
        throwsStateError,
      );
      expect(keluaran.last, contains('kegagalan'));
    });

    group('sesudah reset', () {
      final hive = HiveService();
      late Directory dir;

      setUp(() async {
        dir = await Directory.systemTemp.createTemp('atlas_ops');
        await hive.init(testPath: dir.path);
      });

      tearDown(() async {
        await Hive.close();
        await dir.delete(recursive: true);
      });

      test('siklus sync tidak melaporkan masalah dan tidak mengubah saldo', () async {
        await resetDataUji(
          remote,
          const OpsiCli(konfirmasi: true),
          cetak: keluaran.add,
        );
        await hive.usersBox.put(
          'currentUser',
          UserHiveModel(
            id: oidAgen.oid,
            username: 'a',
            passwordHash: '',
            role: 'pengepul',
            sisaUangJalan: 0,
            waktuDibuat: DateTime(2026),
          ),
        );
        final tulisSebelum = jumlahTulis();

        final laporan = await SyncEngine(
          remote: remote,
          hive: hive,
          unggahFoto: (_) async => null,
        ).siklus();

        expect(laporan.sukses, isTrue, reason: '${laporan.masalah}');
        expect(jumlahTulis(), tulisSebelum);
        expect(hive.usersBox.get('currentUser')!.sisaUangJalan, 900);
      });
    });
  });

  group('isiSaldoDasar', () {
    test('tanpa --confirm: tidak menulis apa pun', () async {
      await isiSaldoDasar(remote, const OpsiCli(), cetak: keluaran.add);

      expect(jumlahTulis(), 0);
      expect(keluaran.join('\n'), contains('DRY-RUN'));
    });

    test('hanya dokumen tanpa field, dan nilai yang sudah ada tidak berubah', () async {
      await isiSaldoDasar(
        remote,
        const OpsiCli(konfirmasi: true),
        cetak: keluaran.add,
      );

      expect(dok('petani', oidPetani)['saldo_dasar_kasbon'], 70000);
      expect(dok('petani', oidPetani)['sisa_hutang_kasbon'], 70000);
      expect(dok('users', oidAgen)['saldo_dasar_uang_jalan'], 900);
      final sudahAda = dok('petani', 'uuid-petani');
      expect(sudahAda['saldo_dasar_kasbon'], 50000);
      expect(sudahAda['sisa_hutang_kasbon'], 20000);
      expect(dok('users', 'manajer-1').containsKey('saldo_dasar_uang_jalan'), isFalse);
    });

    test('dijalankan dua kali: yang kedua tidak menulis apa pun', () async {
      const opsi = OpsiCli(konfirmasi: true);
      await isiSaldoDasar(remote, opsi, cetak: keluaran.add);
      final sebelum = jumlahTulis();

      await isiSaldoDasar(remote, opsi, cetak: keluaran.add);

      expect(jumlahTulis(), sebelum);
    });

    test('dokumen tanpa sisa mendapat nol pada keduanya', () async {
      remote.tanam('petani', {'_id': 'kosong'});

      await isiSaldoDasar(
        remote,
        const OpsiCli(konfirmasi: true),
        cetak: keluaran.add,
      );

      expect(dok('petani', 'kosong')['saldo_dasar_kasbon'], 0);
      expect(dok('petani', 'kosong')['sisa_hutang_kasbon'], 0);
    });

    test('masih ada transaksi: memperingatkan', () async {
      await isiSaldoDasar(remote, const OpsiCli(), cetak: keluaran.add);

      expect(keluaran.join('\n'), contains('PERINGATAN'));
    });

    test('setelah reset: tidak ada peringatan dan tidak ada yang perlu diisi', () async {
      await resetDataUji(
        remote,
        const OpsiCli(konfirmasi: true),
        cetak: keluaran.add,
      );
      keluaran.clear();

      await isiSaldoDasar(remote, const OpsiCli(), cetak: keluaran.add);

      expect(keluaran.join('\n'), isNot(contains('PERINGATAN')));
      expect(keluaran.first, contains(': 0'));
    });
  });
}
