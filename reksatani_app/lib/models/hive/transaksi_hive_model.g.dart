// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaksi_hive_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TransaksiHiveModelAdapter extends TypeAdapter<TransaksiHiveModel> {
  @override
  final int typeId = 3;

  @override
  TransaksiHiveModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TransaksiHiveModel(
      idLokal: fields[0] as String,
      id: fields[1] as String?,
      pengepulId: fields[2] as String,
      petaniId: fields[3] as String,
      namaPengepul: fields[4] as String,
      namaPetani: fields[5] as String,
      namaKomoditas: fields[6] as String,
      gradeTerpilih: fields[7] as String,
      berat: fields[8] as double,
      hargaBeliSatuan: fields[9] as double,
      nominalPotongKasbon: fields[10] as double,
      totalBayar: fields[11] as double,
      fotoFisikBarang: fields[12] as String,
      fotoNota: fields[13] as String,
      latitude: fields[14] as double,
      longitude: fields[15] as double,
      statusSinkronisasi: fields[16] as String,
      createdAt: fields[17] as DateTime,
      waktuDisinkron: fields[18] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, TransaksiHiveModel obj) {
    writer
      ..writeByte(19)
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
      ..write(obj.waktuDisinkron);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransaksiHiveModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
