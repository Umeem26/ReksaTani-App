import 'package:flutter_test/flutter_test.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;
import 'package:reksatani_app/features/manajer_dashboard/controllers/manajemen_pengepul_controller.dart';
import 'package:reksatani_app/features/transaksi_luring/controllers/transaksi_controller.dart';
import 'package:reksatani_app/models/hive/transaksi_hive_model.dart';
import 'package:reksatani_app/services/master_data_service.dart';
import 'package:reksatani_app/services/saldo/transaksi_ledger_service.dart';

import '../../support/fake_remote.dart';
import '../../support/saldo_harness.dart';

/// Dua agen, satu petani bersama, transaksi offline lalu sinkron berurutan, edit,
/// hapus, dan top-up manajer. Semua saldo dan semua bentuk id bercampur.
///
/// Ini tetap memakai fake di memori. Lulus di sini bukan bukti perilaku Atlas.
void main() {
  test('saldo akhir sama dengan saldo_dasar + jumlah delta, dan sinkron ulang tidak mengubah apa pun', () async {
    final remote = FakeRemote();
    final oidAgenA = ObjectId();
    const idAgenB = 'agen-b-uuid';
    final oidPetani = ObjectId();

    tanamAgen(remote, oidAgenA, 1000000);
    tanamAgen(remote, idAgenB, 500000);
    tanamPetani(remote, oidPetani, oidAgenA.oid, 200000);

    final hpA = Perangkat(remote, oidAgenA.oid);
    final hpB = Perangkat(remote, idAgenB);
    await hpA.pasang();
    await hpB.pasang();
    addTearDown(() async {
      await hpA.hancurkan();
      await hpB.hancurkan();
    });

    final trxCtrl = TransaksiController();
    final ledger = TransaksiLedgerService();
    final manajer = ManajemenPengepulController(remote: remote);

    Map<String, dynamic> dok(String koleksi, Object id) =>
        remote.dokumen(koleksi).firstWhere((d) => d['_id'] == id);
    double kasbonCloud() => dok('petani', oidPetani)['sisa_hutang_kasbon'] as double;
    double kasA() => dok('users', oidAgenA)['sisa_uang_jalan'] as double;
    double kasB() => dok('users', idAgenB)['sisa_uang_jalan'] as double;

    Future<TransaksiHiveModel> beli(Perangkat hp, double total, {bool denganPetani = true}) async {
      final lama = hp.hive.transaksiBox.keys.toSet();
      await trxCtrl.simpanTransaksi(
        petaniTerpilih: denganPetani ? hp.petani(oidPetani.oid) : null,
        namaPenjual: 'Pak Tani',
        komoditasTerpilih: komoditasGabah,
        gradeTerpilih: 'A',
        beratText: '1',
        hargaText: total.toStringAsFixed(0),
        fotoNotaPath: '',
        fotoBarangPath: '',
        izinkanTanpaFoto: true,
      );
      await tungguSync();
      return hp.hive.transaksiBox.values.firstWhere((t) => !lama.contains(t.idLokal));
    }

    Future<TransaksiHiveModel> cairkan(Perangkat hp, double nominal) async {
      final lama = hp.hive.transaksiBox.keys.toSet();
      await trxCtrl.simpanKasbonMurni(
        petaniTerpilih: hp.petani(oidPetani.oid),
        nominalKasbonText: nominal.toStringAsFixed(0),
      );
      await tungguSync();
      return hp.hive.transaksiBox.values.firstWhere((t) => !lama.contains(t.idLokal));
    }

    /// Dihitung ulang di sini dengan aritmetika biasa, sengaja tanpa SaldoLedger,
    /// supaya tes tidak hanya membandingkan kode dengan dirinya sendiri.
    void cekInvarian() {
      final trx = remote.dokumen('transaksi');
      var deltaKasbon = 0.0;
      var deltaA = 0.0;
      var deltaB = 0.0;
      for (final d in trx) {
        final total = d['total_bayar'] as double;
        final potongan = d['nominal_potong_kasbon'] as double;
        final pencairan = d['nama_komoditas'] == 'Pencairan Kasbon Baru';
        if (d['petani_id'] == oidPetani.oid) {
          deltaKasbon += pencairan ? total : -potongan;
        }
        final tunai = pencairan ? total : total - potongan;
        if (d['pengepul_id'] == oidAgenA.oid) deltaA -= tunai;
        if (d['pengepul_id'] == idAgenB) deltaB -= tunai;
      }

      final p = dok('petani', oidPetani);
      final a = dok('users', oidAgenA);
      final b = dok('users', idAgenB);
      expect(p['sisa_hutang_kasbon'], (p['saldo_dasar_kasbon'] as double) + deltaKasbon);
      expect(a['sisa_uang_jalan'], (a['saldo_dasar_uang_jalan'] as double) + deltaA);
      expect(b['sisa_uang_jalan'], (b['saldo_dasar_uang_jalan'] as double) + deltaB);
    }

    Future<void> sinkronBerurutan() async {
      await hpA.aktifkan();
      await hpA.sinkron();
      expect(MasterDataService().laporanTerakhir!.sukses, isTrue,
          reason: 'A: ${MasterDataService().laporanTerakhir!.masalah}');
      await hpB.aktifkan();
      await hpB.sinkron();
      expect(MasterDataService().laporanTerakhir!.sukses, isTrue,
          reason: 'B: ${MasterDataService().laporanTerakhir!.masalah}');
      // A sinkron lagi, supaya melihat perubahan B pada petani bersama.
      await hpA.aktifkan();
      await hpA.sinkron();
      expect(MasterDataService().laporanTerakhir!.sukses, isTrue);
    }

    // Keduanya mengambil data awal.
    await sinkronBerurutan();

    // ── Offline: masing-masing bertransaksi tanpa tahu yang lain ──
    remote.online = false;

    await hpA.aktifkan();
    // Yang disimpan kuncinya: objek Hive tidak berlaku lagi setelah berpindah perangkat.
    final idBeliA = (await beli(hpA, 50000)).idLokal; // potongan 50.000, tunai 0
    await cairkan(hpA, 30000); // kasbon +30.000, kas -30.000
    expect(hpA.petani(oidPetani.oid).sisaHutangKasbon, 180000);
    expect(hpA.user.sisaUangJalan, 970000);

    await hpB.aktifkan();
    final idBeliB = (await beli(hpB, 80000)).idLokal; // potongan 80.000, tunai 0
    await beli(hpB, 10000, denganPetani: false); // tunai 10.000
    expect(hpB.petani(oidPetani.oid).sisaHutangKasbon, 120000);
    expect(hpB.user.sisaUangJalan, 490000);

    remote.online = true;

    // ── Manajer menambah kas A selagi transaksi A belum sampai ──
    expect(
      await manajer.editPengepul(
        id: oidAgenA,
        username: 'agen_a',
        sisaUangJalan: 1100000,
        sisaLama: 1000000,
      ),
      HasilEditPengepul.berhasil,
    );

    // ── Sinkron berurutan ──
    await sinkronBerurutan();

    expect(remote.dokumen('transaksi'), hasLength(4));
    // 200.000 - 50.000 + 30.000 - 80.000
    expect(kasbonCloud(), 100000);
    // 1.100.000 - 30.000
    expect(kasA(), 1070000);
    // 500.000 - 10.000
    expect(kasB(), 490000);
    cekInvarian();

    expect(hpA.petani(oidPetani.oid).sisaHutangKasbon, 100000);
    expect(hpA.user.sisaUangJalan, 1070000);

    // ── A mengedit pembeliannya: total 50.000 menjadi 170.000 ──
    // Tersedia 100.000 + 50.000 = 150.000, potongan 150.000, tunai 20.000.
    final beliA = hpA.hive.transaksiBox.get(idBeliA)!;
    await trxCtrl.updateTransaksi(
      beliA,
      petaniTerpilih: hpA.petani(oidPetani.oid),
      namaPenjual: 'Pak Tani',
      komoditasTerpilih: komoditasGabah,
      gradeTerpilih: 'A',
      beratText: '1',
      hargaText: '170000',
      fotoNotaPath: '',
      fotoBarangPath: '',
    );
    await tungguSync();
    expect(beliA.nominalPotongKasbon, 150000);
    expect(hpA.petani(oidPetani.oid).sisaHutangKasbon, 0);
    expect(hpA.user.sisaUangJalan, 1050000);

    await sinkronBerurutan();

    expect(kasbonCloud(), 0);
    expect(kasA(), 1050000);
    cekInvarian();

    // ── B menghapus pembeliannya, dengan balasan deleteOne yang hilang ──
    await hpB.aktifkan();
    final beliB = hpB.hive.transaksiBox.get(idBeliB)!;
    await ledger.hapus(beliB);
    expect(hpB.petani(oidPetani.oid).sisaHutangKasbon, 80000);
    remote.gagalSesudah('deleteOne', 1);
    await hpB.sinkron();
    expect(beliB.statusSinkronisasi, 'pending_delete');
    expect(MasterDataService().laporanTerakhir!.masalah.single.tahap, 'push_hapus');
    // Dokumennya sudah hilang di server, jadi kasbon sudah kembali.
    expect(kasbonCloud(), 80000);

    await sinkronBerurutan();

    expect(remote.dokumen('transaksi'), hasLength(3));
    expect(kasbonCloud(), 80000);
    expect(kasB(), 490000);
    cekInvarian();

    // ── Manajer mengurangi kas B ──
    expect(
      await manajer.editPengepul(
        id: idAgenB,
        username: 'agen_b',
        sisaUangJalan: 390000,
        sisaLama: 490000,
      ),
      HasilEditPengepul.berhasil,
    );

    await sinkronBerurutan();

    expect(kasB(), 390000);
    expect(dok('users', idAgenB)['saldo_dasar_uang_jalan'], 400000);
    cekInvarian();

    // ── Nilai akhir, di cloud dan di kedua HP ──
    expect(kasbonCloud(), 80000);
    expect(kasA(), 1050000);
    await hpA.aktifkan();
    expect(hpA.petani(oidPetani.oid).sisaHutangKasbon, 80000);
    expect(hpA.user.sisaUangJalan, 1050000);
    await hpB.aktifkan();
    expect(hpB.petani(oidPetani.oid).sisaHutangKasbon, 80000);
    expect(hpB.user.sisaUangJalan, 390000);

    // ── Sinkron dua kali tidak mengubah apa pun ──
    final jumlahTulis = remote.panggilan
        .where((p) => p.update != null || p.op == 'deleteOne')
        .length;
    final isi = [
      remote.dokumen('petani'),
      remote.dokumen('users'),
      remote.dokumen('transaksi'),
    ];

    await sinkronBerurutan();
    await sinkronBerurutan();

    expect(
      remote.panggilan.where((p) => p.update != null || p.op == 'deleteOne'),
      hasLength(jumlahTulis),
    );
    expect(remote.dokumen('petani'), isi[0]);
    expect(remote.dokumen('users'), isi[1]);
    expect(remote.dokumen('transaksi'), isi[2]);
    expect(remote.panggilan.where((p) {
      final inc = p.update?[r'$inc'] as Map?;
      return inc != null && p.koleksi != 'users';
    }), isEmpty);
    cekInvarian();
  });
}
