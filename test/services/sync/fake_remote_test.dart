import 'package:flutter_test/flutter_test.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;
import 'package:reksatani_app/services/sync/sync_remote.dart';

import '../../support/fake_remote.dart';

void main() {
  late FakeRemote remote;

  setUp(() => remote = FakeRemote());

  group('Kepekaan tipe BSON', () {
    test('filter string tidak cocok dengan _id ObjectId (bug b3)', () async {
      final oid = ObjectId();
      remote.tanam('petani', {'_id': oid, 'sisa_hutang_kasbon': 100.0});

      final hex = await remote.updateOne('petani', {'_id': oid.oid}, {
        r'$inc': {'sisa_hutang_kasbon': -10.0},
      });
      final literal = await remote.updateOne('petani', {'_id': oid.toString()}, {
        r'$inc': {'sisa_hutang_kasbon': -10.0},
      });

      // Server menjawab sukses, tetapi tidak ada dokumen yang kena.
      expect(hex.ok, isTrue);
      expect(hex.matched, 0);
      expect(literal.matched, 0);
      expect(remote.dokumen('petani').single['sisa_hutang_kasbon'], 100.0);
    });

    test('filter ObjectId tidak cocok dengan _id string yang sama isinya',
        () async {
      final oid = ObjectId();
      remote.tanam('petani', {'_id': oid.oid});

      final hasil = await remote.find('petani', {'_id': oid});

      expect(hasil, isEmpty);
    });

    test(r'$in menjangkau dokumen ObjectId dan string sekaligus', () async {
      final oid = ObjectId();
      remote.tanam('petani', {'_id': oid, 'n': 1});
      remote.tanam('petani', {'_id': 'uuid-1', 'n': 2});

      final a = await remote.find('petani', {
        '_id': {
          r'$in': [oid.oid, oid, oid.toString()],
        },
      });
      final b = await remote.find('petani', {
        '_id': {
          r'$in': ['uuid-1'],
        },
      });

      expect(a.single['n'], 1);
      expect(b.single['n'], 2);
    });

    test('angka dibandingkan nilainya, bukan tipenya', () async {
      remote.tanam('x', {'_id': 'a', 'n': 1});

      expect(await remote.find('x', {'n': 1.0}), hasLength(1));
    });
  });

  group('Operator filter', () {
    test(r'$exists, $ne, $nin, $or', () async {
      remote.tanam('x', {'_id': 'a', 'f': 1});
      remote.tanam('x', {'_id': 'b'});

      expect((await remote.find('x', {'f': {r'$exists': true}})).single['_id'], 'a');
      expect((await remote.find('x', {'f': {r'$exists': false}})).single['_id'], 'b');
      expect((await remote.find('x', {'f': {r'$ne': 1}})).single['_id'], 'b');
      expect((await remote.find('x', {'_id': {r'$nin': ['a']}})).single['_id'], 'b');
      expect(
        await remote.find('x', {
          r'$or': [
            {'_id': 'a'},
            {'_id': 'b'},
          ],
        }),
        hasLength(2),
      );
    });

    test('operator yang tidak dikenal tidak diabaikan diam-diam', () async {
      remote.tanam('x', {'_id': 'a', 'f': 1});

      await expectLater(
        remote.find('x', {'f': {r'$gt': 0}}),
        throwsUnsupportedError,
      );
      await expectLater(
        remote.updateOne('x', {'_id': 'a'}, {
          r'$unset': {'f': ''},
        }),
        throwsUnsupportedError,
      );
    });

    test('hasil find adalah salinan, bukan rujukan ke penyimpanan', () async {
      remote.tanam('x', {'_id': 'a', 'f': 1});

      (await remote.find('x', {})).single['f'] = 99;

      expect(remote.dokumen('x').single['f'], 1);
    });

    test('fields membatasi hasil dan tetap menyertakan _id', () async {
      remote.tanam('x', {'_id': 'a', 'f': 1, 'g': 2});

      final hasil = await remote.find('x', {}, fields: ['f']);

      expect(hasil.single.keys, unorderedEquals(['_id', 'f']));
    });
  });

  group('Update dan upsert', () {
    test('update biasa menulis balasan matched dan modified', () async {
      remote.tanam('x', {'_id': 'a', 'f': 1});

      final berubah = await remote.updateOne('x', {'_id': 'a'}, {
        r'$set': {'f': 2},
      });
      final sama = await remote.updateOne('x', {'_id': 'a'}, {
        r'$set': {'f': 2},
      });

      expect(berubah.matched, 1);
      expect(berubah.modified, 1);
      expect(sama.matched, 1);
      expect(sama.modified, 0);
      expect(sama.kenaDokumen, isTrue);
    });

    test('tidak cocok tanpa upsert: ok true, matched 0, tidak ada dokumen baru',
        () async {
      final hasil = await remote.updateOne('x', {'_id': 'a'}, {
        r'$set': {'f': 2},
      });

      expect(hasil.ok, isTrue);
      expect(hasil.kenaDokumen, isFalse);
      expect(remote.dokumen('x'), isEmpty);
    });

    test(r'upsert baru: filter eq tersalin, $setOnInsert diterapkan, bentuk balasan',
        () async {
      final hasil = await remote.updateOne(
        'x',
        {'id_lokal': 'k1'},
        {
          r'$set': {'f': 1},
          r'$setOnInsert': {'g': 2},
        },
        upsert: true,
      );

      expect(hasil.matched, 1);
      expect(hasil.upserted, 1);
      final dok = remote.dokumen('x').single;
      expect(dok['id_lokal'], 'k1');
      expect(dok['f'], 1);
      expect(dok['g'], 2);
      expect(dok['_id'], isA<ObjectId>());
    });

    test(r'upsert pada dokumen yang ada: $setOnInsert tidak berefek', () async {
      remote.tanam('x', {'_id': 'a', 'id_lokal': 'k1', 'g': 'lama'});

      final hasil = await remote.updateOne(
        'x',
        {'id_lokal': 'k1'},
        {
          r'$set': {'f': 1},
          r'$setOnInsert': {'g': 'baru'},
        },
        upsert: true,
      );

      expect(hasil.upserted, 0);
      expect(remote.dokumen('x').single['g'], 'lama');
      expect(remote.dokumen('x').single['f'], 1);
    });

    test(r'upsert dengan $in banyak nilai membuat _id baru (alasan aturan di MongoId)',
        () async {
      final oid = ObjectId();
      await remote.updateOne(
        'x',
        {
          '_id': {
            r'$in': [oid.oid, oid],
          },
        },
        {
          r'$set': {'f': 1},
        },
        upsert: true,
      );

      final dok = remote.dokumen('x').single;
      expect(dok['_id'] == oid, isFalse);
    });

    test(r'field sama di $set dan $setOnInsert ditolak dengan kode 40', () async {
      final hasil = await remote.updateOne(
        'x',
        {'id_lokal': 'k1'},
        {
          r'$set': {'f': 1},
          r'$setOnInsert': {'f': 2},
        },
        upsert: true,
      );

      expect(hasil.ok, isFalse);
      expect(hasil.errorCode, 40);
      expect(remote.dokumen('x'), isEmpty);
    });

    test(r'$inc menambah, dan menolak nilai bukan angka', () async {
      remote.tanam('x', {'_id': 'a', 'f': 10.0, 's': 'teks'});

      await remote.updateOne('x', {'_id': 'a'}, {
        r'$inc': {'f': -2.5},
      });
      final salah = await remote.updateOne('x', {'_id': 'a'}, {
        r'$inc': {'s': 1},
      });

      expect(remote.dokumen('x').single['f'], 7.5);
      expect(salah.ok, isFalse);
      expect(salah.errorCode, 14);
    });

    test('_id tidak bisa diubah', () async {
      remote.tanam('x', {'_id': 'a'});

      final hasil = await remote.updateOne('x', {'_id': 'a'}, {
        r'$set': {'_id': 'b'},
      });

      expect(hasil.ok, isFalse);
      expect(hasil.errorCode, 66);
    });
  });

  group('Unique index parsial', () {
    test('upsert yang kalah balapan mendapat 11000 tanpa exception', () async {
      remote.buatIndexUnik('transaksi', 'id_lokal');
      remote.balapanUpsert('transaksi', {'id_lokal': 'k1', 'f': 'pihak lain'});

      final hasil = await remote.updateOne(
        'transaksi',
        {'id_lokal': 'k1'},
        {
          r'$set': {'f': 'saya'},
        },
        upsert: true,
      );

      expect(hasil.ok, isFalse);
      expect(hasil.duplikat, isTrue);
      expect(remote.dokumen('transaksi').single['f'], 'pihak lain');
    });

    test('tanpa index, balapan menghasilkan dokumen dobel', () async {
      remote.balapanUpsert('transaksi', {'id_lokal': 'k1', 'f': 'pihak lain'});

      await remote.updateOne(
        'transaksi',
        {'id_lokal': 'k1'},
        {
          r'$set': {'f': 'saya'},
        },
        upsert: true,
      );

      expect(remote.dokumen('transaksi'), hasLength(2));
    });

    test('nilai bukan string tidak terkena index parsial', () async {
      remote.buatIndexUnik('transaksi', 'id_lokal');
      remote.tanam('transaksi', {'_id': 'a'});

      final hasil = await remote.updateOne(
        'transaksi',
        {'_id': 'b'},
        {
          r'$set': {'f': 1},
        },
        upsert: true,
      );

      expect(hasil.upserted, 1);
    });
  });

  group('Penyuntikan gagal', () {
    test('gagalSebelum: tulisan tidak terjadi', () async {
      remote.tanam('x', {'_id': 'a', 'f': 1});
      remote.gagalSebelum('updateOne', 1);

      await expectLater(
        remote.updateOne('x', {'_id': 'a'}, {
          r'$set': {'f': 2},
        }),
        throwsA(isA<RemoteGagal>()),
      );

      expect(remote.dokumen('x').single['f'], 1);
    });

    test('gagalSesudah: tulisan terjadi, klien menerima exception', () async {
      remote.tanam('x', {'_id': 'a', 'f': 1});
      remote.gagalSesudah('updateOne', 1);

      await expectLater(
        remote.updateOne('x', {'_id': 'a'}, {
          r'$set': {'f': 2},
        }),
        throwsA(isA<RemoteGagal>()),
      );

      expect(remote.dokumen('x').single['f'], 2);
    });

    test('hanya berlaku n kali dan bisa dibatasi per koleksi', () async {
      remote.tanam('x', {'_id': 'a'});
      remote.tanam('y', {'_id': 'a'});
      remote.gagalSebelum('updateOne', 1, koleksi: 'y');
      Future<RemoteWrite> tulis(String k) => remote.updateOne(k, {'_id': 'a'}, {
            r'$set': {'f': 1},
          });

      await tulis('x');
      await expectLater(tulis('y'), throwsA(isA<RemoteGagal>()));
      await tulis('y');
    });

    test('gagalSesudah pada deleteOne dan offline', () async {
      remote.tanam('x', {'_id': 'a'});
      remote.gagalSesudah('deleteOne', 1);

      await expectLater(
        remote.deleteOne('x', {'_id': 'a'}),
        throwsA(isA<RemoteGagal>()),
      );
      expect(remote.dokumen('x'), isEmpty);

      remote.online = false;
      expect(await remote.ping(), isFalse);
      await expectLater(remote.find('x', {}), throwsA(isA<RemoteGagal>()));
    });

    test('deleteOne tanpa kecocokan: ok true, removed 0', () async {
      final hasil = await remote.deleteOne('x', {'_id': 'a'});

      expect(hasil.ok, isTrue);
      expect(hasil.removed, 0);
    });
  });
}
