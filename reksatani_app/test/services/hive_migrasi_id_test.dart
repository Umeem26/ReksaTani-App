import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:reksatani_app/models/hive/petani_hive_model.dart';
import 'package:reksatani_app/models/hive/transaksi_hive_model.dart';
import 'package:reksatani_app/models/hive/user_hive_model.dart';
import 'package:reksatani_app/services/hive_service.dart';

const _hexAgen = '65a1b2c3d4e5f60718293a4b';
const _hexPetani = '65a1b2c3d4e5f60718293a4c';
const _literalAgen = 'ObjectId("$_hexAgen")';
const _literalPetani = 'ObjectId("$_hexPetani")';
const _uuid = '3f2b8c1e-9d4a-4c7b-8e21-5a6f0d9c1b23';
const _idLokalLama = '${_literalAgen}_1730000000000';

PetaniHiveModel _petani(String id, {String pengepulId = _literalAgen, double kasbon = 0}) =>
    PetaniHiveModel(
      id: id,
      namaPetani: 'Pak Tani',
      desa: 'Sukamaju',
      pengepulId: pengepulId,
      sisaHutangKasbon: kasbon,
      waktuDibuat: DateTime(2026, 1, 1),
    );

UserHiveModel _user(String id, {double saldo = 500000}) => UserHiveModel(
      id: id,
      username: 'agen',
      passwordHash: 'hash',
      role: 'pengepul',
      sisaUangJalan: saldo,
      waktuDibuat: DateTime(2026, 1, 1),
    );

TransaksiHiveModel _trx(String idLokal, {String status = 'pending'}) =>
    TransaksiHiveModel(
      idLokal: idLokal,
      pengepulId: _literalAgen,
      petaniId: _literalPetani,
      namaPengepul: 'agen',
      namaPetani: 'Pak Tani',
      namaKomoditas: 'Gabah',
      gradeTerpilih: 'A',
      berat: 10,
      hargaBeliSatuan: 5000,
      nominalPotongKasbon: 1000,
      totalBayar: 50000,
      fotoFisikBarang: '',
      fotoNota: '',
      latitude: 0,
      longitude: 0,
      statusSinkronisasi: status,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  final hive = HiveService();
  late Directory dir;

  /// Menjalankan ulang langkah start tanpa menutup box.
  Future<void> jalankanMigrasi() => hive.init(testPath: dir.path);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('hive_migrasi_id');
    await hive.init(testPath: dir.path);
    await hive.settingsBox.delete('idSchemaVersion');
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('petani: kunci, id, dan pengepulId menjadi kanonik, isi lain utuh', () async {
    await hive.petaniBox.put(_literalPetani, _petani(_literalPetani, kasbon: 75000));

    await jalankanMigrasi();

    expect(hive.petaniBox.containsKey(_literalPetani), isFalse);
    final p = hive.petaniBox.get(_hexPetani)!;
    expect(p.id, _hexPetani);
    expect(p.pengepulId, _hexAgen);
    expect(p.sisaHutangKasbon, 75000);
    expect(p.namaPetani, 'Pak Tani');
    expect(p.waktuDibuat, DateTime(2026, 1, 1));
  });

  test('petani UUID: id tetap, pengepulId legacy tetap diperbaiki', () async {
    await hive.petaniBox.put(_uuid, _petani(_uuid));

    await jalankanMigrasi();

    final p = hive.petaniBox.get(_uuid)!;
    expect(p.id, _uuid);
    expect(p.pengepulId, _hexAgen);
    expect(hive.petaniBox, hasLength(1));
  });

  test('users: currentUser tetap di kuncinya, baris agen pindah kunci', () async {
    await hive.usersBox.put('currentUser', _user(_literalAgen, saldo: 123));
    await hive.usersBox.put(_literalAgen, _user(_literalAgen, saldo: 456));

    await jalankanMigrasi();

    expect(hive.usersBox.get('currentUser')!.id, _hexAgen);
    expect(hive.usersBox.get('currentUser')!.sisaUangJalan, 123);
    expect(hive.usersBox.containsKey(_literalAgen), isFalse);
    expect(hive.usersBox.get(_hexAgen)!.sisaUangJalan, 456);
    expect(hive.usersBox.get(_hexAgen)!.passwordHash, 'hash');
  });

  test('transaksi: referensi kanonik, idLokal dan status tidak berubah', () async {
    await hive.transaksiBox.put(_idLokalLama, _trx(_idLokalLama, status: 'pending_update'));

    await jalankanMigrasi();

    final t = hive.transaksiBox.get(_idLokalLama)!;
    expect(t.idLokal, _idLokalLama);
    expect(t.petaniId, _hexPetani);
    expect(t.pengepulId, _hexAgen);
    expect(t.statusSinkronisasi, 'pending_update');
  });

  test('pembanding p.pengepulId == user.id tetap benar setelah migrasi', () async {
    await hive.usersBox.put('currentUser', _user(_literalAgen));
    await hive.petaniBox.put(_literalPetani, _petani(_literalPetani));

    await jalankanMigrasi();

    final user = hive.usersBox.get('currentUser')!;
    expect(hive.petaniBox.values.where((p) => p.pengepulId == user.id), hasLength(1));
  });

  test('dijalankan dua kali menghasilkan keadaan yang sama', () async {
    await hive.usersBox.put('currentUser', _user(_literalAgen));
    await hive.petaniBox.put(_literalPetani, _petani(_literalPetani, kasbon: 10));
    await hive.transaksiBox.put(_idLokalLama, _trx(_idLokalLama));

    await jalankanMigrasi();
    await hive.settingsBox.delete('idSchemaVersion');
    await jalankanMigrasi();

    expect(hive.petaniBox.keys, [_hexPetani]);
    expect(hive.petaniBox.get(_hexPetani)!.sisaHutangKasbon, 10);
    expect(hive.usersBox.get('currentUser')!.id, _hexAgen);
    expect(hive.transaksiBox.get(_idLokalLama)!.petaniId, _hexPetani);
  });

  test('versi tersimpan: migrasi tidak berjalan lagi', () async {
    await jalankanMigrasi();
    expect(hive.settingsBox.get('idSchemaVersion'), 2);

    await hive.petaniBox.put(_literalPetani, _petani(_literalPetani));
    await jalankanMigrasi();

    expect(hive.petaniBox.containsKey(_literalPetani), isTrue);
  });

  group('mati di tengah migrasi (keadaan disiapkan langsung)', () {
    test('kunci baru sudah tertulis, kunci lama belum terhapus', () async {
      await hive.petaniBox.put(_hexPetani, _petani(_hexPetani, pengepulId: _hexAgen, kasbon: 99));
      await hive.petaniBox.put(_literalPetani, _petani(_literalPetani, kasbon: 99));

      await jalankanMigrasi();

      expect(hive.petaniBox.keys, [_hexPetani]);
      expect(hive.petaniBox.get(_hexPetani)!.sisaHutangKasbon, 99);
    });

    test('sebagian baris sudah kanonik, sisanya masih legacy', () async {
      const hexPetaniLain = '65a1b2c3d4e5f60718293a4d';
      await hive.petaniBox.put(hexPetaniLain, _petani(hexPetaniLain, pengepulId: _hexAgen));
      await hive.petaniBox.put(_literalPetani, _petani(_literalPetani));
      await hive.usersBox.put('currentUser', _user(_literalAgen));
      await hive.transaksiBox.put('t1_1', _trx('t1_1'));
      await hive.transaksiBox.put(
        't2_2',
        _trx('t2_2')
          ..petaniId = _hexPetani
          ..pengepulId = _hexAgen,
      );

      await jalankanMigrasi();

      expect(hive.petaniBox.keys, unorderedEquals([hexPetaniLain, _hexPetani]));
      expect(hive.petaniBox.values.every((p) => p.pengepulId == _hexAgen), isTrue);
      expect(hive.transaksiBox.values.every((t) => t.petaniId == _hexPetani), isTrue);
      expect(hive.settingsBox.get('idSchemaVersion'), 2);
    });
  });
}
