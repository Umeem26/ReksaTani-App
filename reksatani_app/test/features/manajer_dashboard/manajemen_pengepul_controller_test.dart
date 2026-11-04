import 'package:flutter_test/flutter_test.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;
import 'package:reksatani_app/features/manajer_dashboard/controllers/manajemen_pengepul_controller.dart';
import 'package:reksatani_app/features/transaksi_luring/controllers/transaksi_controller.dart';

import '../../support/fake_remote.dart';
import '../../support/saldo_harness.dart';

void main() {
  late FakeRemote remote;
  late Perangkat hp;
  late ManajemenPengepulController c;
  final oidAgen = ObjectId();

  Map<String, dynamic> dokAgen() =>
      remote.dokumen('users').firstWhere((d) => d['_id'] == oidAgen);

  Future<HasilEditPengepul> edit({
    Object? id,
    String username = 'agen_baru',
    String? password,
    required double lama,
    required double baru,
  }) =>
      c.editPengepul(
        id: id ?? oidAgen,
        username: username,
        password: password,
        sisaUangJalan: baru,
        sisaLama: lama,
      );

  setUp(() async {
    remote = FakeRemote();
    tanamAgen(remote, oidAgen, 1000000);
    hp = Perangkat(remote, oidAgen.oid);
    await hp.pasang(uangJalan: 1000000);
    c = ManajemenPengepulController(remote: remote);
  });

  tearDown(() => hp.hancurkan());

  group('T15: top-up berbarengan dengan transaksi tertunda', () {
    Future<void> beliOffline(double total) async {
      remote.online = false;
      await TransaksiController().simpanTransaksi(
        petaniTerpilih: null,
        namaPenjual: 'Tanpa Mitra',
        komoditasTerpilih: komoditasGabah,
        gradeTerpilih: 'A',
        beratText: '1',
        hargaText: total.toStringAsFixed(0),
        totalBayar: total,
        fotoNotaPath: '',
        fotoBarangPath: '',
      );
      await tungguSync();
      remote.online = true;
    }

    test('saldo akhir mencakup keduanya, di cloud dan di HP', () async {
      await hp.sinkron();
      await beliOffline(40000);
      expect(hp.user.sisaUangJalan, 960000);

      // Manajer melihat 1.000.000 karena transaksinya belum sampai.
      await edit(lama: 1000000, baru: 1500000);
      expect(dokAgen()['saldo_dasar_uang_jalan'], 1500000);
      expect(dokAgen()['sisa_uang_jalan'], 1500000);

      await hp.sinkron();

      expect(dokAgen()['saldo_dasar_uang_jalan'], 1500000);
      expect(dokAgen()['sisa_uang_jalan'], 1460000);
      expect(hp.user.sisaUangJalan, 1460000);

      await hp.sinkron();

      expect(dokAgen()['sisa_uang_jalan'], 1460000);
      expect(hp.user.sisaUangJalan, 1460000);
    });

    test('transaksi sudah sampai: yang ditambahkan hanya selisih dari yang terlihat', () async {
      await beliOffline(40000);
      await hp.sinkron();
      expect(dokAgen()['sisa_uang_jalan'], 960000);

      await edit(lama: 960000, baru: 1000000);

      expect(dokAgen()['saldo_dasar_uang_jalan'], 1040000);
      expect(dokAgen()['sisa_uang_jalan'], 1000000);

      await hp.sinkron();

      expect(dokAgen()['sisa_uang_jalan'], 1000000);
      expect(hp.user.sisaUangJalan, 1000000);
    });

    test('nilai di form basi: selisihnya tetap utuh', () async {
      // Form dibuka saat saldo 1.000.000, lalu transaksi masuk sebelum disimpan.
      await beliOffline(40000);
      await hp.sinkron();

      await edit(lama: 1000000, baru: 1200000);

      expect(dokAgen()['sisa_uang_jalan'], 1160000);
      await hp.sinkron();
      expect(dokAgen()['sisa_uang_jalan'], 1160000);
      expect(hp.user.sisaUangJalan, 1160000);
    });

    test('saldo dikurangi manajer', () async {
      await edit(lama: 1000000, baru: 700000);
      await hp.sinkron();

      expect(dokAgen()['saldo_dasar_uang_jalan'], 700000);
      expect(hp.user.sisaUangJalan, 700000);
    });
  });

  group('selisihTopUp', () {
    test('angka di form tidak diubah: tidak ada selisih, walau saldo berdesimal', () {
      expect(
        ManajemenPengepulController.selisihTopUp(
            sisaLama: 90000.5, sisaForm: 90000),
        0,
      );
    });

    test('angka diubah: saldo menjadi tepat seperti yang diketik', () {
      expect(
        ManajemenPengepulController.selisihTopUp(
            sisaLama: 90000.5, sisaForm: 100000),
        9999.5,
      );
    });
  });

  group('editPengepul', () {
    test('hanya ganti username: saldo tidak berubah', () async {
      final hasil = await edit(lama: 1000000, baru: 1000000);

      expect(hasil, HasilEditPengepul.berhasil);
      expect(dokAgen()['username'], 'agen_baru');
      expect(dokAgen()['sisa_uang_jalan'], 1000000);
      expect(dokAgen()['saldo_dasar_uang_jalan'], 1000000);
    });

    test('kata sandi kosong tidak menyentuh hash, kata sandi baru di-hash', () async {
      await edit(lama: 0, baru: 0, password: '   ');
      expect(dokAgen().containsKey('password_hash'), isFalse);

      await edit(lama: 0, baru: 0, password: 'rahasia');
      expect(dokAgen()['password_hash'], startsWith(r'$2'));
      expect(dokAgen()['password_hash'], isNot(contains('rahasia')));
    });

    test('nMatched 0: tidakDitemukan, dan pesannya tidak menyebut username', () async {
      final hasil = await edit(id: ObjectId(), lama: 0, baru: 0);

      expect(hasil, HasilEditPengepul.tidakDitemukan);
      final pesan = ManajemenPengepulController.pesanGagalEdit(hasil);
      expect(pesan.toLowerCase(), isNot(contains('username')));
      expect(pesan, contains('tidak ditemukan'));
    });

    test('username dipakai agen lain: pesan lama tetap', () async {
      remote.tanam('users', {'_id': ObjectId(), 'username': 'agen_baru'});

      final hasil = await edit(lama: 0, baru: 0);

      expect(hasil, HasilEditPengepul.usernameDipakai);
      expect(
        ManajemenPengepulController.pesanGagalEdit(hasil),
        contains('sudah digunakan'),
      );
      expect(dokAgen()['username'], isNot('agen_baru'));
    });

    test('username sendiri tidak dianggap bentrok, untuk semua bentuk id', () async {
      await edit(lama: 0, baru: 0);

      expect(await edit(id: oidAgen.oid, lama: 0, baru: 0), HasilEditPengepul.berhasil);
      expect(
        await edit(id: 'ObjectId("${oidAgen.oid}")', lama: 0, baru: 0),
        HasilEditPengepul.berhasil,
      );
    });

    test('koneksi gagal: gagal, bukan tidakDitemukan', () async {
      remote.gagalSebelum('updateOne', 1, koleksi: 'users');

      final hasil = await edit(lama: 0, baru: 5);

      expect(hasil, HasilEditPengepul.gagal);
      expect(
        ManajemenPengepulController.pesanGagalEdit(hasil),
        'Gagal menyimpan data. Periksa koneksi lalu coba lagi.',
      );
    });

    test('ditolak server: gagal, dan tidak mencoba jalur lain', () async {
      remote.tolakBerikutnya('users', 13);

      expect(await edit(lama: 0, baru: 5), HasilEditPengepul.gagal);
      expect(remote.panggilanTulis('users'), hasLength(1));
    });

    test('baris Hive ikut berubah', () async {
      await c.getSemuaPengepul();

      await edit(lama: 1000000, baru: 1250000);

      final m = hp.hive.usersBox.get(oidAgen.oid)!;
      expect(m.username, 'agen_baru');
      expect(m.sisaUangJalan, 1250000);
    });

    group('dokumen belum dimigrasi', () {
      final oidLama = ObjectId();

      setUp(() {
        remote.tanam('users', {
          '_id': oidLama,
          'username': 'lama',
          'role': 'pengepul',
          'sisa_uang_jalan': 300.0,
        });
      });

      test('memakai nilai absolut dan tidak mengarang saldo dasar', () async {
        final hasil = await edit(id: oidLama, username: 'lama2', lama: 300, baru: 500);

        expect(hasil, HasilEditPengepul.berhasil);
        final dok = remote.dokumen('users').firstWhere((d) => d['_id'] == oidLama);
        expect(dok['sisa_uang_jalan'], 500);
        expect(dok['username'], 'lama2');
        expect(dok.containsKey('saldo_dasar_uang_jalan'), isFalse);
      });
    });
  });

  group('tambahPengepul', () {
    test('dokumen baru punya saldo dasar, dan agen itu bisa direkonsiliasi', () async {
      final sukses = await c.tambahPengepul(
        username: ' baru ',
        password: 'sandi',
        sisaUangJalan: 250000,
      );

      expect(sukses, isTrue);
      final dok = remote.dokumen('users').firstWhere((d) => d['username'] == 'baru');
      expect(dok['_id'], isA<String>());
      expect(dok['role'], 'pengepul');
      expect(dok['saldo_dasar_uang_jalan'], 250000);
      expect(dok['sisa_uang_jalan'], 250000);
      expect(dok['password_hash'], startsWith(r'$2'));
      expect(hp.hive.usersBox.get(dok['_id'])!.sisaUangJalan, 250000);

      final hpBaru = Perangkat(remote, dok['_id'] as String);
      await hpBaru.pasang();
      await hpBaru.sinkron();

      expect(hpBaru.user.sisaUangJalan, 250000);
      await hpBaru.hancurkan();
      await hp.aktifkan();
    });

    test('username sudah ada: ditolak tanpa menulis', () async {
      await c.editPengepul(
        id: oidAgen,
        username: 'ada',
        sisaUangJalan: 0,
        sisaLama: 0,
      );
      final sebelum = remote.panggilanTulis('users').length;

      final sukses = await c.tambahPengepul(
        username: 'ada',
        password: 'x',
        sisaUangJalan: 1,
      );

      expect(sukses, isFalse);
      expect(remote.panggilanTulis('users'), hasLength(sebelum));
    });

    test('koneksi gagal: false, tanpa baris lokal', () async {
      remote.online = false;

      expect(
        await c.tambahPengepul(username: 'x', password: 'x', sisaUangJalan: 1),
        isFalse,
      );
      expect(hp.hive.usersBox.values.where((u) => u.username == 'x'), isEmpty);
    });
  });

  group('getSemuaPengepul', () {
    test('mengembalikan dokumen apa adanya dan menyimpan ke Hive dengan id kanonik', () async {
      remote.tanam('users', {'_id': ObjectId(), 'role': 'manajer'});

      final docs = await c.getSemuaPengepul();

      expect(docs, hasLength(1));
      expect(docs.single['_id'], oidAgen);
      expect(hp.hive.usersBox.get(oidAgen.oid)!.sisaUangJalan, 1000000);
    });

    test('offline: daftar dari Hive', () async {
      await c.getSemuaPengepul();
      remote.online = false;

      final docs = await c.getSemuaPengepul();

      expect(docs.map((d) => d['_id']), contains(oidAgen.oid));
    });
  });

  group('hapusPengepul', () {
    test('terhapus di cloud dan Hive, untuk bentuk id hex', () async {
      await c.getSemuaPengepul();

      expect(await c.hapusPengepul(oidAgen.oid), isTrue);

      expect(remote.dokumen('users'), isEmpty);
      expect(hp.hive.usersBox.containsKey(oidAgen.oid), isFalse);
    });

    test('koneksi gagal: false dan baris lokal tetap', () async {
      await c.getSemuaPengepul();
      remote.online = false;

      expect(await c.hapusPengepul(oidAgen), isFalse);
      expect(hp.hive.usersBox.containsKey(oidAgen.oid), isTrue);
    });
  });
}
