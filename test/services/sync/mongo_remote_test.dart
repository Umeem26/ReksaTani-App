import 'package:flutter_test/flutter_test.dart';
// ignore: implementation_imports
import 'package:mongo_dart/src/database/commands/query_and_write_operation_commands/return_classes/abstract_write_result.dart';
// ignore: implementation_imports
import 'package:mongo_dart/src/database/commands/query_and_write_operation_commands/return_classes/write_result.dart';
import 'package:reksatani_app/services/sync/mongo_remote.dart';
import 'package:reksatani_app/services/sync/sync_report.dart';

import '../../support/fake_remote.dart';

void main() {
  group('MongoRemote.petakan (balasan simulasi, bukan dari Atlas)', () {
    WriteResult hasil(WriteCommandType tipe, Map<String, dynamic> balasan) =>
        WriteResult.fromMap(tipe, balasan);

    test('filter tidak cocok: ok true tetapi tidak kena dokumen (F3)', () {
      final w = MongoRemote.petakan(
          hasil(WriteCommandType.update, {'ok': 1.0, 'n': 0, 'nModified': 0}));

      expect(w.ok, isTrue);
      expect(w.matched, 0);
      expect(w.kenaDokumen, isFalse);
    });

    test('cocok tanpa perubahan nilai tetap kena dokumen', () {
      final w = MongoRemote.petakan(
          hasil(WriteCommandType.update, {'ok': 1.0, 'n': 1, 'nModified': 0}));

      expect(w.matched, 1);
      expect(w.modified, 0);
      expect(w.kenaDokumen, isTrue);
    });

    test('upsert baru: matched 1 dan upserted 1', () {
      final w = MongoRemote.petakan(hasil(WriteCommandType.update, {
        'ok': 1.0,
        'n': 1,
        'nModified': 0,
        'upserted': [
          {'index': 0, '_id': 'x'},
        ],
      }));

      expect(w.matched, 1);
      expect(w.upserted, 1);
      expect(w.kenaDokumen, isTrue);
    });

    test('write error 11000 tidak melempar dan terbaca sebagai duplikat', () {
      final w = MongoRemote.petakan(hasil(WriteCommandType.update, {
        'ok': 1.0,
        'n': 0,
        'writeErrors': [
          {'index': 0, 'code': 11000, 'errmsg': 'E11000'},
        ],
      }));

      expect(w.ok, isFalse);
      expect(w.duplikat, isTrue);
      expect(w.kenaDokumen, isFalse);
    });

    test('ok 0 tanpa writeErrors: kode dibaca dari balasan', () {
      final w = MongoRemote.petakan(hasil(WriteCommandType.update, {
        'ok': 0.0,
        'code': 40,
        'errmsg': 'conflict',
      }));

      expect(w.ok, isFalse);
      expect(w.errorCode, 40);
    });

    test('write concern error dianggap gagal', () {
      final w = MongoRemote.petakan(hasil(WriteCommandType.update, {
        'ok': 1.0,
        'n': 1,
        'writeConcernError': {'code': 64, 'errmsg': 'timeout'},
      }));

      expect(w.ok, isFalse);
    });

    test('delete: removed dibaca dari n', () {
      final ada = MongoRemote.petakan(
          hasil(WriteCommandType.delete, {'ok': 1.0, 'n': 1}));
      final tidakAda = MongoRemote.petakan(
          hasil(WriteCommandType.delete, {'ok': 1.0, 'n': 0}));

      expect(ada.removed, 1);
      expect(ada.ok, isTrue);
      expect(tidakAda.removed, 0);
      expect(tidakAda.ok, isTrue);
    });
  });

  group('Fake meniru bentuk balasan driver', () {
    test('upsert baru pada fake sama bentuknya dengan hasil petakan', () async {
      final fake = FakeRemote();
      final dariFake = await fake.updateOne(
        'x',
        {'id_lokal': 'k'},
        {
          r'$set': {'f': 1},
        },
        upsert: true,
      );
      final dariDriver = MongoRemote.petakan(
        WriteResult.fromMap(WriteCommandType.update, {
          'ok': 1.0,
          'n': 1,
          'nModified': 0,
          'upserted': [
            {'index': 0, '_id': 'x'},
          ],
        }),
      );

      expect(dariFake.matched, dariDriver.matched);
      expect(dariFake.modified, dariDriver.modified);
      expect(dariFake.upserted, dariDriver.upserted);
      expect(dariFake.ok, dariDriver.ok);
    });
  });

  group('SyncReport', () {
    test('sukses hanya bila tidak ada masalah, dan daftarnya tidak bisa diubah', () {
      final kosong =
          SyncReport(masalah: const [], terkirim: 2, selesai: DateTime(2026));
      final ada = SyncReport(
        masalah: const [
          SyncIssue(tahap: 't', jenis: 'j', pesan: 'p'),
        ],
        terkirim: 0,
        selesai: DateTime(2026),
      );

      expect(kosong.sukses, isTrue);
      expect(ada.sukses, isFalse);
      expect(() => ada.masalah.clear(), throwsUnsupportedError);
    });
  });
}
