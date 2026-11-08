import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mongo_dart/mongo_dart.dart' show Db, DbCollection;
// ignore: implementation_imports
import 'package:mongo_dart/src/database/commands/query_and_write_operation_commands/return_classes/write_result.dart';
import 'package:reksatani_app/features/auth/controllers/auth_controller.dart';
import 'package:reksatani_app/services/mongodb_service.dart';
import 'package:reksatani_app/services/sync/mongo_remote.dart';

/// Semua tes di file ini memakai `Db` palsu lewat `MongoDatabase.pembuka`, jadi
/// tidak ada yang menyentuh jaringan atau Atlas. Karena itu perilaku `Db` asli
/// tidak teruji di sini; lihat uji asap di runbook.
class _DbPalsu implements Db {
  _DbPalsu({this.findOneMenggantung = false, this.closeMenggantung = false});

  final bool findOneMenggantung;
  final bool closeMenggantung;
  bool terhubung = true;
  int jumlahTutup = 0;

  @override
  bool get isConnected => terhubung;

  @override
  Future close() {
    jumlahTutup++;
    terhubung = false;
    return closeMenggantung ? Completer<void>().future : Future.value();
  }

  @override
  DbCollection collection(String collectionName) =>
      _KoleksiPalsu(menggantung: findOneMenggantung);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _KoleksiPalsu implements DbCollection {
  _KoleksiPalsu({required this.menggantung});

  final bool menggantung;

  @override
  Future<Map<String, dynamic>?> findOne([dynamic selector]) => menggantung
      ? Completer<Map<String, dynamic>?>().future
      : Future.value(const <String, dynamic>{'_id': 'x'});

  @override
  dynamic noSuchMethod(Invocation i) {
    if (i.memberName == #updateOne || i.memberName == #deleteOne) {
      return Completer<WriteResult>().future;
    }
    if (i.memberName == #modernFind) {
      return StreamController<Map<String, dynamic>>().stream;
    }
    return super.noSuchMethod(i);
  }
}

void main() {
  late int jumlahBuka;

  void pakaiPembuka(Future<Db> Function() pembuka) {
    MongoDatabase.pembuka = () {
      jumlahBuka++;
      return pembuka();
    };
  }

  setUp(() {
    jumlahBuka = 0;
    MongoDatabase.batasSambung = const Duration(milliseconds: 100);
    MongoDatabase.batasPing = const Duration(milliseconds: 100);
    MongoDatabase.batasTutup = const Duration(milliseconds: 100);
    pakaiPembuka(() async => throw StateError('pembuka belum diatur tes ini'));
  });

  tearDown(() async {
    await MongoDatabase.close();
  });

  test('getCollection sebelum terhubung melempar MongoTidakTerhubung', () {
    expect(
      () => MongoDatabase.getCollection('users'),
      throwsA(isA<MongoTidakTerhubung>()),
    );
  });

  test('close sebelum terhubung tidak melempar', () async {
    await MongoDatabase.close();
  });

  test('a3: mulai offline, ping false tanpa crash, lalu pulih tanpa restart', () async {
    pakaiPembuka(() async => throw Exception('tidak ada DNS'));
    expect(await MongoDatabase.ping(), isFalse);

    pakaiPembuka(() async => _DbPalsu());
    expect(await MongoDatabase.ping(), isTrue);

    expect(MongoDatabase.getCollection('users'), isA<DbCollection>());
  });

  test('single-flight: panggilan bersamaan hanya membuka satu koneksi', () async {
    final gerbang = Completer<Db>();
    pakaiPembuka(() => gerbang.future);

    final a = MongoDatabase.connect();
    final b = MongoDatabase.connect();
    final c = MongoDatabase.ping();
    gerbang.complete(_DbPalsu());
    await Future.wait([a, b]);

    expect(await c, isTrue);
    expect(jumlahBuka, 1);
  });

  test('_db hanya terisi setelah terbuka', () async {
    final gerbang = Completer<Db>();
    pakaiPembuka(() => gerbang.future);

    final proses = MongoDatabase.connect();
    expect(
      () => MongoDatabase.getCollection('users'),
      throwsA(isA<MongoTidakTerhubung>()),
    );

    gerbang.complete(_DbPalsu());
    await proses;
    expect(MongoDatabase.getCollection('users'), isA<DbCollection>());
  });

  test('sambung ulang menutup koneksi lama', () async {
    final pertama = _DbPalsu();
    pakaiPembuka(() async => pertama);
    await MongoDatabase.connect();

    pakaiPembuka(() async => _DbPalsu());
    await MongoDatabase.connect();

    expect(pertama.jumlahTutup, 1);
  });

  test('pembuka menggantung: ping false, lalu upaya berikutnya tidak terhalang', () async {
    final gerbang = Completer<Db>();
    pakaiPembuka(() => gerbang.future);

    expect(await MongoDatabase.ping(), isFalse);
    // Beri waktu timeout internal `_sambung` selesai dan melepas single-flight.
    await Future<void>.delayed(const Duration(milliseconds: 150));

    pakaiPembuka(() async => _DbPalsu());
    expect(await MongoDatabase.ping(), isTrue);

    // Upaya lama yang ternyata berhasil belakangan tidak boleh tertinggal terbuka.
    final telat = _DbPalsu();
    gerbang.complete(telat);
    await Future<void>.delayed(Duration.zero);
    expect(telat.jumlahTutup, 1);
  });

  test('socket setengah mati: ping false, koneksi dibuang, ping berikut membuka baru', () async {
    final mati = _DbPalsu(findOneMenggantung: true);
    pakaiPembuka(() async => mati);
    expect(await MongoDatabase.ping(), isFalse);
    expect(mati.jumlahTutup, 1);
    expect(
      () => MongoDatabase.getCollection('users'),
      throwsA(isA<MongoTidakTerhubung>()),
    );

    pakaiPembuka(() async => _DbPalsu());
    expect(await MongoDatabase.ping(), isTrue);
    expect(jumlahBuka, 2);
  });

  test('close yang menggantung tidak menahan pemanggil', () async {
    pakaiPembuka(() async => _DbPalsu(closeMenggantung: true));
    await MongoDatabase.connect();

    await MongoDatabase.close();

    expect(
      () => MongoDatabase.getCollection('users'),
      throwsA(isA<MongoTidakTerhubung>()),
    );
  });

  test('login saat offline mencoba tersambung dan memberi pesan koneksi', () async {
    pakaiPembuka(() async => throw Exception('offline'));
    final auth = AuthController();

    final hasil = await auth.login('agen', 'rahasia');

    expect(hasil, isFalse);
    expect(jumlahBuka, 1);
    expect(auth.errorMessage.value, contains('Koneksi internet'));
    expect(auth.isLoading.value, isFalse);
  });

  group('MongoRemote: operasi yang menggantung berakhir dengan timeout', () {
    final remote = MongoRemote(
      koleksi: (_) => _KoleksiPalsu(menggantung: true),
      batasOperasi: const Duration(milliseconds: 50),
    );

    test('updateOne', () async {
      await expectLater(
        remote.updateOne('x', {}, {r'$set': {'a': 1}}),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('deleteOne', () async {
      await expectLater(
        remote.deleteOne('x', {}),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('find', () async {
      await expectLater(
        remote.find('x', {}),
        throwsA(isA<TimeoutException>()),
      );
    });
  });
}
