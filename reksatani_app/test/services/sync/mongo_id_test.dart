import 'package:flutter_test/flutter_test.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;
import 'package:reksatani_app/services/sync/mongo_id.dart';

import '../../support/fake_remote.dart';

void main() {
  final oid = ObjectId();
  final hex = oid.oid;
  final literal = 'ObjectId("$hex")';
  const uuid = '3f2b8c1e-9d4a-4c7b-8e21-5a6f0d9c1b23';

  group('kanonik', () {
    test('ObjectId menjadi hex, bukan literal toString', () {
      expect(MongoId.kanonik(oid), hex);
      expect(oid.toString(), literal);
    });

    test('literal legacy menjadi hex', () {
      expect(MongoId.kanonik(literal), hex);
    });

    test('hex dan UUID tetap', () {
      expect(MongoId.kanonik(hex), hex);
      expect(MongoId.kanonik(uuid), uuid);
    });

    test('null menjadi string kosong', () {
      expect(MongoId.kanonik(null), '');
    });

    test('idempoten', () {
      for (final raw in [oid, hex, literal, uuid, null]) {
        final sekali = MongoId.kanonik(raw);
        expect(MongoId.kanonik(sekali), sekali);
      }
    });

    test('literal yang tidak utuh tidak diperlakukan sebagai ObjectId', () {
      expect(MongoId.kanonik('${literal}_123'), '${literal}_123');
    });
  });

  group('kandidat', () {
    test('hex, ObjectId, dan literal menghasilkan tiga bentuk yang sama', () {
      for (final raw in [oid, hex, literal]) {
        expect(MongoId.kandidat(raw), [hex, oid, literal]);
      }
    });

    test('UUID hanya menghasilkan string', () {
      expect(MongoId.kandidat(uuid), [uuid]);
    });

    test('null hanya menghasilkan string kosong', () {
      expect(MongoId.kandidat(null), ['']);
    });
  });

  group('filter terhadap fake yang peka tipe (b3)', () {
    late FakeRemote remote;
    final inc = {
      r'$inc': {'saldo': -10.0},
    };

    setUp(() => remote = FakeRemote());

    test('reproduksi bug: filter string lama tidak mengenai dokumen ObjectId',
        () async {
      remote.tanam('petani', {'_id': oid, 'saldo': 100.0});

      for (final idLokal in [hex, literal]) {
        final w = await remote.updateOne('petani', {'_id': idLokal}, inc);
        expect(w.ok, isTrue);
        expect(w.matched, 0);
      }
      expect(remote.dokumen('petani').single['saldo'], 100.0);
    });

    test('filterId mengenai dokumen ObjectId dari bentuk apa pun', () async {
      remote.tanam('petani', {'_id': oid, 'saldo': 100.0});

      for (final raw in [oid, hex, literal]) {
        final w =
            await remote.updateOne('petani', MongoId.filterId(raw), inc);
        expect(w.matched, 1);
      }
      expect(remote.dokumen('petani').single['saldo'], 70.0);
    });

    test('filterId mengenai dokumen _id string UUID', () async {
      remote.tanam('petani', {'_id': uuid, 'saldo': 100.0});

      final w = await remote.updateOne('petani', MongoId.filterId(uuid), inc);

      expect(w.matched, 1);
    });

    test('filterId mengenai dokumen _id string 24-hex', () async {
      remote.tanam('petani', {'_id': hex, 'saldo': 100.0});

      final w = await remote.updateOne('petani', MongoId.filterId(oid), inc);

      expect(w.matched, 1);
    });

    test('id yang tidak ada: matched 0, jadi pemanggil harus memeriksanya',
        () async {
      remote.tanam('petani', {'_id': oid, 'saldo': 100.0});

      final w =
          await remote.updateOne('petani', MongoId.filterId(ObjectId()), inc);

      expect(w.ok, isTrue);
      expect(w.kenaDokumen, isFalse);
    });

    test('filterRef menjangkau referensi literal legacy dan bentuk baru',
        () async {
      remote.tanam('transaksi', {'_id': 'a', 'pengepul_id': literal});
      remote.tanam('transaksi', {'_id': 'b', 'pengepul_id': hex});
      remote.tanam('transaksi', {'_id': 'c', 'pengepul_id': oid});
      remote.tanam('transaksi', {'_id': 'd', 'pengepul_id': uuid});

      final hasil = await remote.find(
          'transaksi', MongoId.filterRef('pengepul_id', oid));

      expect(hasil.map((d) => d['_id']), unorderedEquals(['a', 'b', 'c']));
    });
  });

  group('sama', () {
    test('membandingkan lintas bentuk', () {
      expect(MongoId.sama(oid, hex), isTrue);
      expect(MongoId.sama(literal, oid), isTrue);
      expect(MongoId.sama(uuid, hex), isFalse);
    });
  });

  group('idLokalBuatanAplikasi', () {
    test('format aplikasi, termasuk yang memuat literal lama', () {
      expect(MongoId.idLokalBuatanAplikasi('${hex}_1730000000000'), isTrue);
      expect(MongoId.idLokalBuatanAplikasi('${literal}_1730000000000'), isTrue);
      expect(MongoId.idLokalBuatanAplikasi('kasbon_${uuid}_1730000000000'), isTrue);
    });

    test('kunci dari _id dokumen tanpa id_lokal', () {
      expect(MongoId.idLokalBuatanAplikasi(literal), isFalse);
      expect(MongoId.idLokalBuatanAplikasi(hex), isFalse);
      expect(MongoId.idLokalBuatanAplikasi(uuid), isFalse);
    });
  });
}
