import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:reksatani_app/models/hive/transaksi_hive_model.dart';

/// Menulis baris transaksi seperti versi aplikasi sebelum `3c4a6fa`:
/// hanya field 0 sampai 19, tanpa `isManualGrading`.
class _AdapterTransaksiTanpaField20 extends TypeAdapter<TransaksiHiveModel> {
  @override
  final int typeId = 3;

  @override
  TransaksiHiveModel read(BinaryReader reader) =>
      throw UnimplementedError('Hanya dipakai untuk menulis');

  @override
  void write(BinaryWriter writer, TransaksiHiveModel obj) {
    writer
      ..writeByte(20)
      ..writeByte(0)
      ..write(obj.idLokal)
      ..writeByte(1)
      ..write(obj.id)
      ..writeByte(2)
      ..write(obj.pengepulId)
      ..writeByte(3)
      ..write(obj.petaniId)
      ..writeByte(4)
      ..write(obj.namaPengepul)
      ..writeByte(5)
      ..write(obj.namaPetani)
      ..writeByte(6)
      ..write(obj.namaKomoditas)
      ..writeByte(7)
      ..write(obj.gradeTerpilih)
      ..writeByte(8)
      ..write(obj.berat)
      ..writeByte(9)
      ..write(obj.hargaBeliSatuan)
      ..writeByte(10)
      ..write(obj.nominalPotongKasbon)
      ..writeByte(11)
      ..write(obj.totalBayar)
      ..writeByte(12)
      ..write(obj.fotoFisikBarang)
      ..writeByte(13)
      ..write(obj.fotoNota)
      ..writeByte(14)
      ..write(obj.latitude)
      ..writeByte(15)
      ..write(obj.longitude)
      ..writeByte(16)
      ..write(obj.statusSinkronisasi)
      ..writeByte(17)
      ..write(obj.createdAt)
      ..writeByte(18)
      ..write(obj.waktuDisinkron)
      ..writeByte(19)
      ..write(obj.skorKeyakinan);
  }
}

TransaksiHiveModel _trx(String idLokal) => TransaksiHiveModel(
      idLokal: idLokal,
      pengepulId: 'agen',
      petaniId: 'petani',
      namaPengepul: 'Agen',
      namaPetani: 'Petani',
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
      statusSinkronisasi: 'pending',
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('hive_format_lama');
    Hive.init(dir.path);
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  group('T18: box format lama dibaca adapter baru', () {
    test('transaksi tanpa field 20 terbuka dengan default, datanya utuh', () async {
      Hive.registerAdapter<TransaksiHiveModel>(
        _AdapterTransaksiTanpaField20(),
        override: true,
      );
      final lama = await Hive.openBox<TransaksiHiveModel>('transaksiBox');
      await lama.put('t1', _trx('t1'));
      await lama.close();

      Hive.registerAdapter<TransaksiHiveModel>(
        TransaksiHiveModelAdapter(),
        override: true,
      );
      final baru = await Hive.openBox<TransaksiHiveModel>('transaksiBox');

      final t = baru.get('t1')!;
      expect(t.isManualGrading, isFalse);
      expect(t.statusSinkronisasi, 'pending');
      expect(t.nominalPotongKasbon, 1000);
    });

    test('nilai true yang tersimpan tidak tertimpa default', () async {
      Hive.registerAdapter<TransaksiHiveModel>(
        TransaksiHiveModelAdapter(),
        override: true,
      );
      final box = await Hive.openBox<TransaksiHiveModel>('transaksiBox');
      await box.put('t1', _trx('t1')..isManualGrading = true);
      await box.close();

      final lagi = await Hive.openBox<TransaksiHiveModel>('transaksiBox');

      expect(lagi.get('t1')!.isManualGrading, isTrue);
    });
  });
}
