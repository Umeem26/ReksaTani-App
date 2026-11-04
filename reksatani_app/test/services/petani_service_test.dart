import 'package:flutter_test/flutter_test.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;
import 'package:reksatani_app/models/hive/petani_hive_model.dart';
import 'package:reksatani_app/features/transaksi_luring/controllers/transaksi_controller.dart';
import 'package:reksatani_app/features/pengepul_dashboard/controllers/beranda_controller.dart';
import 'package:reksatani_app/services/master_data_service.dart';
import 'package:reksatani_app/services/petani_service.dart';
import 'package:reksatani_app/services/saldo/transaksi_ditolak.dart';

import '../support/fake_remote.dart';
import '../support/saldo_harness.dart';

void main() {
  final oidAgen = ObjectId();
  late FakeRemote remote;
  late Perangkat hp;
  final svc = PetaniService();

  Map<String, dynamic>? dok(String koleksi, Object id) {
    for (final d in remote.dokumen(koleksi)) {
      if (d['_id'] == id) return d;
    }
    return null;
  }

  setUp(() async {
    remote = FakeRemote();
    tanamAgen(remote, oidAgen, 1000000);
    hp = Perangkat(remote, oidAgen.oid);
    await hp.pasang(uangJalan: 1000000);
  });

  tearDown(() async {
    await tungguSync();
    await hp.hancurkan();
  });

  group('T11: petani dibuat offline', () {
    test('tidak hilang saat offline, lalu terkirim dengan _id yang sama', () async {
      remote.online = false;
      final p = await svc.tambah(nama: 'Bu Tani', desa: 'Cibiru');
      await tungguSync();

      expect(p.statusSinkronisasi, 'pending');
      expect(hp.hive.petaniBox.containsKey(p.id), isTrue);
      expect(remote.dokumen('petani'), isEmpty);

      remote.online = true;
      await hp.sinkron();

      final d = dok('petani', p.id)!;
      expect(p.statusSinkronisasi, 'synced');
      expect(identical(hp.hive.petaniBox.get(p.id), p), isTrue);
      expect(d['nama_petani'], 'Bu Tani');
      expect(d['desa'], 'Cibiru');
      expect(d['pengepul_id'], oidAgen.oid);
      expect(d['saldo_dasar_kasbon'], 0);
      expect(d['sisa_hutang_kasbon'], 0);
      expect(d['waktu_dibuat'], p.waktuDibuat.toIso8601String());
    });

    test('pencairan offline pada petani baru terhitung setelah online', () async {
      remote.online = false;
      final p = await svc.tambah(nama: 'Bu Tani', desa: 'Cibiru');
      await tungguSync();
      await TransaksiController().simpanKasbonMurni(
        petaniTerpilih: p,
        nominalKasbonText: '50000',
      );
      await tungguSync();
      expect(p.sisaHutangKasbon, 50000);

      remote.online = true;
      await hp.sinkron();

      expect(dok('petani', p.id)!['sisa_hutang_kasbon'], 50000);
      expect(dok('users', oidAgen)!['sisa_uang_jalan'], 950000);
      expect(p.sisaHutangKasbon, 50000);
      expect(hp.user.sisaUangJalan, 950000);
    });

    test('kiriman gagal: baris tidak hilang saat pull di siklus yang sama', () async {
      final p = await svc.tambah(nama: 'Bu Tani', desa: 'Cibiru');
      await tungguSync();
      p.statusSinkronisasi = 'pending';
      await p.save();
      await remote.deleteOne('petani', {'_id': p.id});
      remote.gagalSebelum('updateOne', 1, koleksi: 'petani');

      await hp.sinkron();

      expect(hp.hive.petaniBox.containsKey(p.id), isTrue);
      expect(p.statusSinkronisasi, 'pending');
      expect(
        MasterDataService().laporanTerakhir!.masalah.map((m) => m.tahap),
        contains('push_petani'),
      );

      await hp.sinkron();

      expect(dok('petani', p.id), isNotNull);
      expect(p.statusSinkronisasi, 'synced');
    });

    test('balasan upsert hilang: satu dokumen, tetap antre lalu synced', () async {
      remote.online = false;
      final p = await svc.tambah(nama: 'Bu Tani', desa: 'Cibiru');
      await tungguSync();
      remote.online = true;
      remote.gagalSesudah('updateOne', 1, koleksi: 'petani');

      await hp.sinkron();
      expect(p.statusSinkronisasi, 'pending');
      expect(remote.dokumen('petani'), hasLength(1));

      await hp.sinkron();
      expect(p.statusSinkronisasi, 'synced');
      expect(remote.dokumen('petani'), hasLength(1));
    });
  });

  group('Ubah', () {
    test('ubah offline bertahan dari pull, lalu terkirim ke dokumen ObjectId', () async {
      final oid = ObjectId();
      tanamPetani(remote, oid, oidAgen.oid, 0);
      await hp.sinkron();
      final p = hp.petani(oid.oid);

      remote.online = false;
      await svc.ubah(p, nama: 'Nama Baru', desa: 'Desa Baru');
      await tungguSync();
      expect(p.statusSinkronisasi, 'pending_update');

      // Push gagal, pull tetap berjalan: nama lokal tidak boleh mundur.
      remote.online = true;
      remote.gagalSebelum('updateOne', 1, koleksi: 'petani');
      await hp.sinkron();
      expect(p.namaPetani, 'Nama Baru');
      expect(p.statusSinkronisasi, 'pending_update');

      await hp.sinkron();
      expect(p.statusSinkronisasi, 'synced');
      expect(dok('petani', oid)!['nama_petani'], 'Nama Baru');
      expect(dok('petani', oid)!['desa'], 'Desa Baru');
    });

    test('ubah baris pending tetap pending, supaya dokumennya terbuat', () async {
      remote.online = false;
      final p = await svc.tambah(nama: 'A', desa: 'B');
      await tungguSync();
      await svc.ubah(p, nama: 'A2', desa: 'B2');
      await tungguSync();
      expect(p.statusSinkronisasi, 'pending');

      remote.online = true;
      await hp.sinkron();

      expect(dok('petani', p.id)!['nama_petani'], 'A2');
    });

    test('diubah selama pengiriman: tetap di antrean dan terkirim berikutnya', () async {
      final oid = ObjectId();
      tanamPetani(remote, oid, oidAgen.oid, 0);
      await hp.sinkron();
      final p = hp.petani(oid.oid);
      p
        ..namaPetani = 'Satu'
        ..statusSinkronisasi = 'pending_update';
      await p.save();
      remote.saatMenungguBalasan = () async {
        p.namaPetani = 'Dua';
        await p.save();
      };

      await hp.sinkron();
      expect(p.statusSinkronisasi, 'pending_update');
      expect(p.namaPetani, 'Dua');

      await hp.sinkron();
      expect(p.statusSinkronisasi, 'synced');
      expect(dok('petani', oid)!['nama_petani'], 'Dua');
    });

    test('dokumen hilang tanpa kasbon: SyncIssue dan baris lokal dihapus', () async {
      final oid = ObjectId();
      tanamPetani(remote, oid, oidAgen.oid, 0);
      await hp.sinkron();
      final p = hp.petani(oid.oid);
      await remote.deleteOne('petani', {'_id': oid});
      remote.online = false;
      await svc.ubah(p, nama: 'X', desa: 'Y');
      await tungguSync();
      remote.online = true;

      await hp.sinkron();

      final jenis = MasterDataService().laporanTerakhir!.masalah.map((m) => m.jenis);
      expect(jenis, contains('dokumen_hilang'));
      expect(hp.hive.petaniBox.containsKey(oid.oid), isFalse);
      expect(remote.dokumen('petani'), isEmpty);
    });

    test('dokumen hilang dengan kasbon: baris dipertahankan', () async {
      final oid = ObjectId();
      tanamPetani(remote, oid, oidAgen.oid, 0);
      await hp.sinkron();
      final p = hp.petani(oid.oid);
      await remote.deleteOne('petani', {'_id': oid});
      remote.online = false;
      p.sisaHutangKasbon = 5000;
      await svc.ubah(p, nama: 'X', desa: 'Y');
      await tungguSync();
      remote.online = true;

      await hp.sinkron();

      expect(hp.hive.petaniBox.containsKey(oid.oid), isTrue);
      expect(p.statusSinkronisasi, 'pending_update');
    });
  });

  group('Hapus', () {
    test('P9: berkasbon ditolak, tidak ada yang berubah', () async {
      final oid = ObjectId();
      tanamPetani(remote, oid, oidAgen.oid, 75000);
      await hp.sinkron();
      final p = hp.petani(oid.oid);

      await expectLater(
        svc.hapus(p),
        throwsA(isA<TransaksiDitolak>().having((e) => e.kode, 'kode', 'petani_berkasbon')),
      );

      expect(p.statusSinkronisasi, 'synced');
      await tungguSync();
      expect(dok('petani', oid), isNotNull);
      expect(hp.hive.petaniBox.containsKey(oid.oid), isTrue);
    });

    test('tanpa kasbon: dokumen ObjectId benar-benar terhapus dan tidak muncul lagi', () async {
      final oid = ObjectId();
      tanamPetani(remote, oid, oidAgen.oid, 0);
      await hp.sinkron();

      await svc.hapus(hp.petani(oid.oid));
      await tungguSync();
      await hp.sinkron();

      expect(dok('petani', oid), isNull);
      expect(hp.hive.petaniBox.containsKey(oid.oid), isFalse);
    });

    test('offline: langsung hilang dari daftar, tetap ada di antrean, lalu terhapus', () async {
      final oid = ObjectId();
      tanamPetani(remote, oid, oidAgen.oid, 0);
      await hp.sinkron();
      remote.online = false;

      await svc.hapus(hp.petani(oid.oid));
      await tungguSync();

      expect(MasterDataService().getDaftarPetani(), isEmpty);
      expect(TransaksiController().daftarPetani, isEmpty);
      expect(BerandaController().mitraTerbaru, isEmpty);
      expect(hp.hive.petaniBox.containsKey(oid.oid), isTrue);
      expect(dok('petani', oid), isNotNull);

      remote.online = true;
      await hp.sinkron();

      expect(dok('petani', oid), isNull);
      expect(hp.hive.petaniBox.containsKey(oid.oid), isFalse);
    });

    test('baris pending yang upsert-nya sudah sampai tidak muncul lagi (F9)', () async {
      remote.online = false;
      final p = await svc.tambah(nama: 'A', desa: 'B');
      await tungguSync();
      remote.online = true;
      remote.gagalSesudah('updateOne', 1, koleksi: 'petani');
      await hp.sinkron();
      expect(dok('petani', p.id), isNotNull);
      expect(p.statusSinkronisasi, 'pending');

      await svc.hapus(p);
      await tungguSync();
      await hp.sinkron();

      expect(dok('petani', p.id), isNull);
      expect(hp.hive.petaniBox.containsKey(p.id), isFalse);
    });

    test('kasbon masuk dari perangkat lain: batal dihapus dan kembali tampil', () async {
      final oid = ObjectId();
      tanamPetani(remote, oid, oidAgen.oid, 0);
      await hp.sinkron();
      remote.online = false;
      await svc.hapus(hp.petani(oid.oid));
      await tungguSync();

      remote.tanam('transaksi', {
        'id_lokal': 'kasbon_lain_1',
        'pengepul_id': 'agen-lain',
        'petani_id': oid.oid,
        'nama_komoditas': 'Pencairan Kasbon',
        'total_bayar': 40000.0,
        'nominal_potong_kasbon': 0.0,
      });
      remote.online = true;
      await hp.sinkron();

      expect(dok('petani', oid)!['sisa_hutang_kasbon'], 40000);
      final p = hp.petani(oid.oid);
      expect(p.statusSinkronisasi, 'synced');
      expect(p.sisaHutangKasbon, 40000);
      expect(MasterDataService().getDaftarPetani(), hasLength(1));
      expect(
        MasterDataService().laporanTerakhir!.masalah.map((m) => m.jenis),
        contains('hapus_petani_ditolak'),
      );
    });

    test('rekonsiliasi gagal: tidak dihapus sampai kasbon cloud diketahui', () async {
      final oid = ObjectId();
      tanamPetani(remote, oid, oidAgen.oid, 0);
      await hp.sinkron();
      remote.online = false;
      await svc.hapus(hp.petani(oid.oid));
      await tungguSync();
      remote.online = true;
      remote.gagalSebelum('find', 1, koleksi: 'transaksi');

      await hp.sinkron();

      expect(dok('petani', oid), isNotNull);
      expect(hp.petani(oid.oid).statusSinkronisasi, 'pending_delete');

      await hp.sinkron();
      expect(dok('petani', oid), isNull);
    });

    test('dokumen sudah terhapus di cloud: retry tetap membersihkan baris lokal', () async {
      final oid = ObjectId();
      tanamPetani(remote, oid, oidAgen.oid, 0);
      await hp.sinkron();
      remote.online = false;
      await svc.hapus(hp.petani(oid.oid));
      await tungguSync();
      remote.online = true;
      await remote.deleteOne('petani', {'_id': oid});

      await hp.sinkron();

      expect(hp.hive.petaniBox.containsKey(oid.oid), isFalse);
    });

    test('transaksi pending yang memotong petani tetap sampai sebelum dihapus', () async {
      final oid = ObjectId();
      tanamPetani(remote, oid, oidAgen.oid, 10000);
      await hp.sinkron();
      remote.online = false;
      await TransaksiController().simpanTransaksi(
        petaniTerpilih: hp.petani(oid.oid),
        namaPenjual: 'Pak',
        komoditasTerpilih: komoditasGabah,
        gradeTerpilih: 'A',
        beratText: '1',
        hargaText: '10000',
        totalBayar: 10000,
        fotoNotaPath: '',
        fotoBarangPath: '',
      );
      await tungguSync();
      expect(hp.petani(oid.oid).sisaHutangKasbon, 0);
      await svc.hapus(hp.petani(oid.oid));
      await tungguSync();

      remote.online = true;
      await hp.sinkron();

      expect(remote.dokumen('transaksi'), hasLength(1));
      expect(dok('petani', oid), isNull);
      expect(hp.hive.petaniBox.containsKey(oid.oid), isFalse);
    });
  });

  group('Merge dan sync pertama sesudah upgrade', () {
    PetaniHiveModel barisLama(String id, {String? pemilik}) => PetaniHiveModel(
          id: id,
          namaPetani: 'Lama',
          desa: 'Lama',
          pengepulId: pemilik ?? oidAgen.oid,
          sisaHutangKasbon: 0,
          waktuDibuat: DateTime(2026),
        );

    test('baris UUID milik agen yang tidak ada di cloud dikirim, bukan dihapus', () async {
      await hp.hive.petaniBox.put('uuid-1', barisLama('uuid-1'));

      await hp.sinkron();
      expect(hp.petani('uuid-1').statusSinkronisasi, 'pending');

      await hp.sinkron();
      expect(dok('petani', 'uuid-1'), isNotNull);
      expect(hp.petani('uuid-1').statusSinkronisasi, 'synced');
    });

    test('baris ber-id ObjectId tidak dikirim ulang: _id-nya bukan milik perangkat', () async {
      final hex = ObjectId().oid;
      await hp.hive.petaniBox.put(hex, barisLama(hex));

      await hp.sinkron();

      expect(hp.hive.petaniBox.containsKey(hex), isFalse);
      expect(remote.dokumen('petani'), isEmpty);
    });

    test('baris UUID milik agen lain dihapus', () async {
      await hp.hive.petaniBox.put('uuid-2', barisLama('uuid-2', pemilik: 'agen-lain'));

      await hp.sinkron();

      expect(hp.hive.petaniBox.containsKey('uuid-2'), isFalse);
      expect(remote.dokumen('petani'), isEmpty);
    });

    test('sesudah sync pertama: baris synced yang tidak ada di cloud dihapus', () async {
      await hp.sinkron();
      await hp.hive.petaniBox.put('uuid-3', barisLama('uuid-3'));

      await hp.sinkron();

      expect(hp.hive.petaniBox.containsKey('uuid-3'), isFalse);
      expect(remote.dokumen('petani'), isEmpty);
    });

    test('pull gagal: tidak ada baris yang berubah dan penanda belum terpasang', () async {
      await hp.hive.petaniBox.put('uuid-4', barisLama('uuid-4'));
      remote.gagalSebelum('find', 1, koleksi: 'petani', lewati: 1);

      await hp.sinkron();

      expect(hp.petani('uuid-4').statusSinkronisasi, 'synced');
      expect(hp.hive.settingsBox.get('petaniAntreanAktif'), isNull);
    });
  });
}
