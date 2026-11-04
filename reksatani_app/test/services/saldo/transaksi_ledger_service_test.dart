import 'package:flutter_test/flutter_test.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;
import 'package:reksatani_app/features/pengepul_dashboard/controllers/beranda_controller.dart';
import 'package:reksatani_app/features/pengepul_dashboard/controllers/riwayat_controller.dart';
import 'package:reksatani_app/features/transaksi_luring/controllers/transaksi_controller.dart';
import 'package:reksatani_app/models/hive/transaksi_hive_model.dart';
import 'package:reksatani_app/services/master_data_service.dart';
import 'package:reksatani_app/services/saldo/transaksi_ditolak.dart';
import 'package:reksatani_app/services/saldo/transaksi_ledger_service.dart';

import '../../support/fake_remote.dart';
import '../../support/saldo_harness.dart';

const _agen = 'agen-1';
const _petani = 'petani-a';

void main() {
  late FakeRemote remote;
  late Perangkat hp;
  late TransaksiController c;
  late TransaksiLedgerService ledger;

  double kasbonCloud() =>
      remote.dokumen('petani').single['sisa_hutang_kasbon'] as double;
  double uangJalanCloud() =>
      remote.dokumen('users').single['sisa_uang_jalan'] as double;

  /// Box mengurutkan menurut kunci, jadi baris terakhir bukan berarti yang terbaru.
  TransaksiHiveModel barisBaru(Set<dynamic> kunciLama) => hp.hive.transaksiBox
      .get(hp.hive.transaksiBox.keys.firstWhere((k) => !kunciLama.contains(k)))!;

  Future<TransaksiHiveModel> beli(double total) async {
    final lama = hp.hive.transaksiBox.keys.toSet();
    await c.simpanTransaksi(
      petaniTerpilih: hp.petani(_petani),
      namaPenjual: 'Pak Tani',
      komoditasTerpilih: komoditasGabah,
      gradeTerpilih: 'A',
      beratText: '1',
      hargaText: total.toStringAsFixed(0),
      totalBayar: total,
      fotoNotaPath: '',
      fotoBarangPath: '',
    );
    await tungguSync();
    return barisBaru(lama);
  }

  Future<TransaksiHiveModel> cairkan(double nominal) async {
    final lama = hp.hive.transaksiBox.keys.toSet();
    await c.simpanKasbonMurni(
      petaniTerpilih: hp.petani(_petani),
      nominalKasbonText: nominal.toStringAsFixed(0),
    );
    await tungguSync();
    return barisBaru(lama);
  }

  void cekSaldo(double kasbon, double uangJalan) {
    expect(kasbonCloud(), kasbon, reason: 'kasbon cloud');
    expect(uangJalanCloud(), uangJalan, reason: 'uang jalan cloud');
    expect(hp.petani(_petani).sisaHutangKasbon, kasbon, reason: 'kasbon lokal');
    expect(hp.user.sisaUangJalan, uangJalan, reason: 'uang jalan lokal');
  }

  setUp(() async {
    remote = FakeRemote();
    tanamAgen(remote, _agen, 1000000);
    tanamPetani(remote, _petani, _agen, 100000);
    hp = Perangkat(remote, _agen);
    await hp.pasang(uangJalan: 1000000);
    await hp.sinkron();
    c = TransaksiController();
    ledger = TransaksiLedgerService();
  });

  tearDown(() => hp.hancurkan());

  group('T6: hapus mengembalikan saldo', () {
    test('pembelian: lokal langsung, cloud setelah sync', () async {
      final t = await beli(150000);
      cekSaldo(0, 950000);

      remote.online = false;
      await ledger.hapus(t);

      expect(hp.petani(_petani).sisaHutangKasbon, 100000);
      expect(hp.user.sisaUangJalan, 1000000);
      expect(t.statusSinkronisasi, 'pending_delete');
      expect(kasbonCloud(), 0);

      remote.online = true;
      await hp.sinkron();

      cekSaldo(100000, 1000000);
      expect(remote.dokumen('transaksi'), isEmpty);
      expect(hp.hive.transaksiBox.containsKey(t.idLokal), isFalse);
    });

    test('pencairan: hutang berkurang dan kas kembali', () async {
      final t = await cairkan(25000);
      cekSaldo(125000, 975000);

      await ledger.hapus(t);
      await hp.sinkron();

      cekSaldo(100000, 1000000);
      expect(remote.dokumen('transaksi'), isEmpty);
    });

    test('transaksi yang diedit: yang dikembalikan adalah nilai sesudah edit', () async {
      final t = await beli(50000);
      remote.online = false;
      await c.updateTransaksi(
        t,
        petaniTerpilih: hp.petani(_petani),
        namaPenjual: 'Pak Tani',
        komoditasTerpilih: komoditasGabah,
        gradeTerpilih: 'A',
        beratText: '1',
        hargaText: '130000',
        totalBayar: 130000,
        fotoNotaPath: '',
        fotoBarangPath: '',
      );
      await tungguSync();
      expect(t.statusSinkronisasi, 'pending_update');

      await ledger.hapus(t);
      expect(hp.petani(_petani).sisaHutangKasbon, 100000);
      expect(hp.user.sisaUangJalan, 1000000);

      remote.online = true;
      await hp.sinkron();

      cekSaldo(100000, 1000000);
    });
  });

  group('T7: hapus diulang', () {
    test('balasan deleteOne hilang: retry n=0 berhasil dan saldo tidak kembali dua kali', () async {
      final t = await beli(50000);
      await ledger.hapus(t);
      remote.gagalSesudah('deleteOne', 1);

      await hp.sinkron();

      expect(remote.dokumen('transaksi'), isEmpty);
      expect(t.statusSinkronisasi, 'pending_delete');
      expect(MasterDataService().laporanTerakhir!.masalah.single.tahap, 'push_hapus');
      cekSaldo(100000, 1000000);

      await hp.sinkron();

      expect(hp.hive.transaksiBox.containsKey(t.idLokal), isFalse);
      expect(MasterDataService().laporanTerakhir!.sukses, isTrue);
      cekSaldo(100000, 1000000);
    });

    test('mati sesudah deleteOne, sebelum baris dihapus: tidak kembali dua kali', () async {
      final t = await beli(50000);
      await ledger.hapus(t);
      // Dokumen sudah terhapus di server, tetapi baris lokal masih menunggu.
      await remote.deleteOne('transaksi', {'id_lokal': t.idLokal});

      await hp.sinkron();

      expect(remote.panggilan.where((p) => p.update?.containsKey(r'$inc') ?? false), isEmpty);
      cekSaldo(100000, 1000000);
    });

    test('hapus dipanggil dua kali: saldo lokal dikembalikan sekali', () async {
      final t = await beli(50000);
      remote.online = false;

      await ledger.hapus(t);
      await ledger.hapus(t);

      expect(hp.petani(_petani).sisaHutangKasbon, 100000);
      expect(hp.user.sisaUangJalan, 1000000);
    });

    test('dua panggilan bersamaan: saldo lokal dikembalikan sekali', () async {
      final t = await beli(50000);
      remote.online = false;

      await Future.wait([ledger.hapus(t), ledger.hapus(t)]);

      expect(hp.petani(_petani).sisaHutangKasbon, 100000);
      expect(hp.user.sisaUangJalan, 1000000);
    });

    test('deleteOne ditolak dengan exception sebelum diterapkan: baris tetap menunggu', () async {
      final t = await beli(50000);
      await ledger.hapus(t);
      remote.gagalSebelum('deleteOne', 1);

      await hp.sinkron();

      expect(remote.dokumen('transaksi'), hasLength(1));
      expect(t.statusSinkronisasi, 'pending_delete');
      // Cloud masih menghitung dokumennya, lokal sudah tidak.
      expect(kasbonCloud(), 50000);
      expect(hp.petani(_petani).sisaHutangKasbon, 100000);
      expect(hp.user.sisaUangJalan, 1000000);

      await hp.sinkron();

      cekSaldo(100000, 1000000);
    });
  });

  group('T8: hapus baris pending yang ternyata sudah ada di cloud (F9)', () {
    test('tidak muncul lagi setelah pull, dan saldo benar', () async {
      final t = await beli(50000);
      // Upsert sampai, tetapi status lokal belum sempat tersimpan.
      t.statusSinkronisasi = 'pending';
      await t.save();
      remote.online = false;

      await ledger.hapus(t);

      expect(t.statusSinkronisasi, 'pending_delete');
      expect(hp.hive.transaksiBox.containsKey(t.idLokal), isTrue);

      remote.online = true;
      await hp.sinkron();

      expect(remote.dokumen('transaksi'), isEmpty);
      expect(hp.hive.transaksiBox.containsKey(t.idLokal), isFalse);
      cekSaldo(100000, 1000000);

      await hp.sinkron();

      expect(hp.hive.transaksiBox.containsKey(t.idLokal), isFalse);
    });

    test('baris pending yang belum pernah sampai: selesai tanpa dokumen', () async {
      remote.online = false;
      final t = await beli(50000);

      await ledger.hapus(t);
      remote.online = true;
      await hp.sinkron();

      expect(remote.dokumen('transaksi'), isEmpty);
      expect(hp.hive.transaksiBox.containsKey(t.idLokal), isFalse);
      cekSaldo(100000, 1000000);
    });

    test('dihapus selagi upsert menunggu balasan: dokumennya ikut terhapus di siklus itu', () async {
      remote.online = false;
      final t = await beli(50000);
      remote.online = true;
      remote.saatMenungguBalasan = () => ledger.hapus(t);

      await hp.sinkron();

      expect(remote.dokumen('transaksi'), isEmpty);
      expect(hp.hive.transaksiBox.containsKey(t.idLokal), isFalse);
      cekSaldo(100000, 1000000);
    });
  });

  group('Baris tanpa id_lokal', () {
    test('ObjectId: dokumen terhapus lewat _id dan tidak kembali', () async {
      final oid = ObjectId();
      remote.tanam('transaksi', {
        '_id': oid,
        'pengepul_id': _agen,
        'petani_id': _petani,
        'nama_komoditas': 'Gabah',
        'total_bayar': 50000.0,
        'nominal_potong_kasbon': 10000.0,
      });
      await hp.sinkron();
      cekSaldo(90000, 960000);
      final t = hp.hive.transaksiBox.get(oid.toString())!;

      await ledger.hapus(t);
      await hp.sinkron();

      expect(remote.dokumen('transaksi'), isEmpty);
      expect(hp.hive.transaksiBox.containsKey(oid.toString()), isFalse);
      cekSaldo(100000, 1000000);
    });

    test('_id string UUID: dokumen terhapus lewat _id', () async {
      const uuid = '3f2c1b7a-9a53-4c55-8c1e-1234567890ab';
      remote.tanam('transaksi', {
        '_id': uuid,
        'pengepul_id': _agen,
        'petani_id': _petani,
        'nama_komoditas': 'Gabah',
        'total_bayar': 50000.0,
        'nominal_potong_kasbon': 0.0,
      });
      await hp.sinkron();
      final t = hp.hive.transaksiBox.get(uuid)!;

      await ledger.hapus(t);
      await hp.sinkron();

      expect(remote.dokumen('transaksi'), isEmpty);
      cekSaldo(100000, 1000000);
    });

    test('retry setelah balasan hilang: n=0 tetap sukses', () async {
      final oid = ObjectId();
      remote.tanam('transaksi', {
        '_id': oid,
        'pengepul_id': _agen,
        'nama_komoditas': 'Gabah',
        'total_bayar': 50000.0,
      });
      await hp.sinkron();
      final t = hp.hive.transaksiBox.get(oid.toString())!;
      await ledger.hapus(t);
      remote.gagalSesudah('deleteOne', 1);

      await hp.sinkron();
      await hp.sinkron();

      expect(hp.hive.transaksiBox.containsKey(oid.toString()), isFalse);
      expect(uangJalanCloud(), 1000000);
      expect(hp.user.sisaUangJalan, 1000000);
    });
  });

  group('P4: pencairan yang sudah terpakai', () {
    test('ditolak dan tidak ada yang berubah', () async {
      final pencairan = await cairkan(25000);
      await beli(125000);
      cekSaldo(0, 975000);

      await expectLater(
        ledger.hapus(pencairan),
        throwsA(isA<TransaksiDitolak>()
            .having((e) => e.kode, 'kode', 'pencairan_terpakai')),
      );

      expect(pencairan.statusSinkronisasi, 'synced');
      cekSaldo(0, 975000);
    });

    test('terpakai sebagian tetapi masih tertutup kasbon: boleh', () async {
      final pencairan = await cairkan(25000);
      await beli(10000);
      cekSaldo(115000, 975000);

      await ledger.hapus(pencairan);
      await hp.sinkron();

      cekSaldo(90000, 1000000);
    });

    test('setelah pembelian yang memotongnya dihapus, pencairan bisa dihapus', () async {
      final pencairan = await cairkan(25000);
      final pembelian = await beli(125000);

      await ledger.hapus(pembelian);
      await ledger.hapus(pencairan);
      await hp.sinkron();

      cekSaldo(100000, 1000000);
      expect(remote.dokumen('transaksi'), isEmpty);
    });
  });

  group('Controller memakai satu jalur', () {
    test('RiwayatController: baris pending lewat pending_delete, penolakan diteruskan', () async {
      final ctrl = RiwayatController();
      addTearDown(ctrl.dispose);
      remote.online = false;
      final t = await beli(50000);

      await ctrl.hapusTransaksi(t);
      await tungguSync();

      expect(t.statusSinkronisasi, 'pending_delete');
      expect(ctrl.filteredTransaksi, isEmpty);

      remote.online = true;
      final pencairan = await cairkan(25000);
      await beli(125000);
      await expectLater(
        ctrl.hapusTransaksi(pencairan),
        throwsA(isA<TransaksiDitolak>()),
      );
    });

    test('BerandaController: sama, dan angka ringkasan tidak memuat baris terhapus', () async {
      final ctrl = BerandaController();
      remote.online = false;
      final t = await beli(50000);
      expect(ctrl.jumlahTransaksi, 1);

      await ctrl.hapusTransaksi(t);
      await tungguSync();

      expect(t.statusSinkronisasi, 'pending_delete');
      expect(ctrl.jumlahTransaksi, 0);
      expect(ctrl.totalBerat, 0);
      expect(ctrl.riwayatTerbaru, isEmpty);
      expect(hp.user.sisaUangJalan, 1000000);
    });
  });

  test('transaksi milik agen lain di perangkat ini tidak mengubah kas sendiri', () async {
    remote.online = false;
    final t = await beli(50000);
    t.pengepulId = 'agen-lain';
    await t.save();
    final kas = hp.user.sisaUangJalan;

    await ledger.hapus(t);

    expect(hp.user.sisaUangJalan, kas);
  });
}
