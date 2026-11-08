import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;
import 'package:reksatani_app/models/hive/transaksi_hive_model.dart';
import 'package:reksatani_app/services/saldo/saldo_ledger.dart';

Map<String, dynamic> _dok(
  String idLokal, {
  Object? petani = 'p1',
  Object? agen = 'a1',
  String komoditas = 'Gabah',
  num total = 100,
  num potongan = 30,
  String? waktu,
}) =>
    {
      '_id': 'dok_$idLokal',
      'id_lokal': idLokal,
      'petani_id': petani,
      'pengepul_id': agen,
      'nama_komoditas': komoditas,
      'total_bayar': total,
      'nominal_potong_kasbon': potongan,
      'waktu_disinkron': ?waktu,
    };

TransaksiHiveModel _baris(
  String idLokal,
  String status, {
  double total = 100,
  double potongan = 30,
  String petani = 'p1',
  String komoditas = 'Gabah',
}) =>
    TransaksiHiveModel(
      idLokal: idLokal,
      pengepulId: 'a1',
      petaniId: petani,
      namaPengepul: '',
      namaPetani: '',
      namaKomoditas: komoditas,
      gradeTerpilih: '',
      berat: 0,
      hargaBeliSatuan: 0,
      nominalPotongKasbon: potongan,
      totalBayar: total,
      fotoFisikBarang: '',
      fotoNota: '',
      latitude: 0,
      longitude: 0,
      statusSinkronisasi: status,
      createdAt: DateTime(2026),
    );

void main() {
  group('hitung', () {
    test('pembelian dan pencairan dijumlahkan per petani dan per agen', () {
      final r = SaldoLedger.hitung([
        _dok('1'),
        _dok('2', komoditas: 'Pencairan Kasbon Baru', total: 50, potongan: 0),
        _dok('3', petani: 'p2', agen: 'a2', total: 10, potongan: 10),
      ]);

      expect(r.deltaKasbon('p1'), -30 + 50);
      expect(r.deltaKasbon('p2'), -10);
      expect(r.deltaUangJalan('a1'), -70 - 50);
      expect(r.deltaUangJalan('a2'), 0);
      expect(r.deltaKasbon('tidak-ada'), 0);
    });

    test('semua bentuk id jatuh ke satu kelompok', () {
      final oid = ObjectId();
      final r = SaldoLedger.hitung([
        _dok('1', petani: oid),
        _dok('2', petani: oid.oid),
        _dok('3', petani: 'ObjectId("${oid.oid}")'),
      ]);

      expect(r.deltaKasbon(oid), -90);
      expect(r.deltaKasbon(oid.oid), -90);
    });

    test('transaksi tanpa petani tidak masuk kasbon, tetapi masuk uang jalan', () {
      final r = SaldoLedger.hitung([_dok('1', petani: '', potongan: 0)]);

      expect(r.deltaKasbon(''), 0);
      expect(r.deltaUangJalan('a1'), -100);
    });

    test('nilai bukan angka dihitung nol, tidak melempar', () {
      final d = _dok('1')
        ..['total_bayar'] = 'rusak'
        ..['nominal_potong_kasbon'] = null;

      expect(SaldoLedger.hitung([d]).deltaUangJalan('a1'), 0);
    });
  });

  group('duplikat id_lokal (T13)', () {
    test('dihitung sekali', () {
      final a = _dok('1')..['_id'] = 'x';
      final b = _dok('1')..['_id'] = 'y';

      expect(SaldoLedger.hitung([a, b]).deltaKasbon('p1'), -30);
    });

    test('duplikat berbeda isi: yang terakhir disinkron, apa pun urutannya', () {
      final lama = _dok('1', potongan: 30, waktu: '2026-01-01');
      final baru = _dok('1', potongan: 80, waktu: '2026-02-01');

      expect(SaldoLedger.hitung([lama, baru]).deltaKasbon('p1'), -80);
      expect(SaldoLedger.hitung([baru, lama]).deltaKasbon('p1'), -80);
    });

    test('tanpa waktu sinkron: pilihan tetap tidak bergantung urutan', () {
      final a = _dok('1', potongan: 30)..['_id'] = 'a';
      final b = _dok('1', potongan: 80)..['_id'] = 'b';

      expect(
        SaldoLedger.hitung([a, b]).deltaKasbon('p1'),
        SaldoLedger.hitung([b, a]).deltaKasbon('p1'),
      );
    });

    test('dokumen tanpa id_lokal berdiri sendiri, memakai _id', () {
      final a = _dok('x')
        ..remove('id_lokal')
        ..['_id'] = ObjectId();
      final b = _dok('x')
        ..['id_lokal'] = ''
        ..['_id'] = ObjectId();

      expect(SaldoLedger.hitung([a, b]).deltaKasbon('p1'), -60);
      expect(SaldoLedger.kunciDokumen(a), a['_id'].toString());
    });
  });

  group('efektif', () {
    test('baris pending yang belum ada di cloud ikut terhitung', () {
      final r = SaldoLedger.efektif([_dok('1')], [_baris('2', 'pending')]);

      expect(r.deltaKasbon('p1'), -60);
    });

    test('baris pending yang dokumennya sudah sampai tidak terhitung dua kali', () {
      final r = SaldoLedger.efektif([_dok('1')], [_baris('1', 'pending')]);

      expect(r.deltaKasbon('p1'), -30);
    });

    test('pending_update menimpa dokumen, termasuk ganti petani', () {
      final r = SaldoLedger.efektif(
        [_dok('1')],
        [_baris('1', 'pending_update', potongan: 5, petani: 'p2')],
      );

      expect(r.deltaKasbon('p1'), 0);
      expect(r.deltaKasbon('p2'), -5);
      expect(r.deltaUangJalan('a1'), -95);
    });

    test('pending_delete mengeluarkan dokumen', () {
      final r =
          SaldoLedger.efektif([_dok('1')], [_baris('1', 'pending_delete')]);

      expect(r.deltaKasbon('p1'), 0);
      expect(r.deltaUangJalan('a1'), 0);
    });

    test('baris synced tidak mengubah apa pun', () {
      final r = SaldoLedger.efektif(
        [_dok('1')],
        [_baris('1', 'synced', potongan: 99)],
      );

      expect(r.deltaKasbon('p1'), -30);
    });

    test('tanpa baris lokal sama dengan hitung', () {
      final d = [_dok('1'), _dok('2')];

      expect(
        SaldoLedger.efektif(d, const []).deltaKasbon('p1'),
        SaldoLedger.hitung(d).deltaKasbon('p1'),
      );
    });
  });

  group('saldo', () {
    test('galat double tidak terlihat', () {
      expect(SaldoLedger.saldo(0.1, 0.2), 0.3);
      expect(SaldoLedger.saldo(100000, -0.1 - 0.2), 99999.7);
    });

    test('nilai negatif tidak di-clamp', () {
      expect(SaldoLedger.saldo(100, -150), -50);
    });
  });

  group('sifat', () {
    final acak = Random(20261104);
    final dokumen = [
      for (var i = 0; i < 200; i++)
        _dok(
          '$i',
          petani: 'p${acak.nextInt(5)}',
          agen: 'a${acak.nextInt(3)}',
          komoditas: i % 7 == 0 ? 'Pencairan Kasbon Baru' : 'Gabah',
          total: acak.nextInt(100000) + acak.nextDouble(),
          potongan: i % 7 == 0 ? 0 : acak.nextInt(1000) + acak.nextDouble(),
        ),
    ];

    test('urutan transaksi tidak memengaruhi hasil', () {
      final asal = SaldoLedger.hitung(dokumen);

      for (var ulang = 0; ulang < 20; ulang++) {
        final kocok = SaldoLedger.hitung(dokumen.toList()..shuffle(acak));
        for (var p = 0; p < 5; p++) {
          expect(
            SaldoLedger.saldo(1000, kocok.deltaKasbon('p$p')),
            SaldoLedger.saldo(1000, asal.deltaKasbon('p$p')),
          );
        }
        for (var a = 0; a < 3; a++) {
          expect(
            SaldoLedger.saldo(1000, kocok.deltaUangJalan('a$a')),
            SaldoLedger.saldo(1000, asal.deltaUangJalan('a$a')),
          );
        }
      }
    });

    test('dihitung dua kali memberi nilai yang sama', () {
      final a = SaldoLedger.hitung(dokumen).deltaKasbon('p1');
      final b = SaldoLedger.hitung(dokumen).deltaKasbon('p1');

      expect(a, b);
    });

    test('menyalin semua dokumen menjadi duplikat tidak mengubah hasil', () {
      final ganda = SaldoLedger.hitung([...dokumen, ...dokumen]);
      final tunggal = SaldoLedger.hitung(dokumen);

      for (var p = 0; p < 5; p++) {
        expect(ganda.deltaKasbon('p$p'), tunggal.deltaKasbon('p$p'));
      }
    });
  });
}
