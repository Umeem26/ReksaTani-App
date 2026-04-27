// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'komoditas_hive_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class KomoditasHiveModelAdapter extends TypeAdapter<KomoditasHiveModel> {
  @override
  final int typeId = 2;

  @override
  KomoditasHiveModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return KomoditasHiveModel(
      id: fields[0] as String,
      namaKomoditas: fields[1] as String,
      unitSatuan: fields[2] as String,
      gradeKualitas: (fields[3] as List)
          .map((dynamic e) => (e as Map).cast<String, dynamic>())
          .toList(),
      diperbaruiOleh: fields[4] as String,
      waktuPembaruan: fields[5] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, KomoditasHiveModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.namaKomoditas)
      ..writeByte(2)
      ..write(obj.unitSatuan)
      ..writeByte(3)
      ..write(obj.gradeKualitas)
      ..writeByte(4)
      ..write(obj.diperbaruiOleh)
      ..writeByte(5)
      ..write(obj.waktuPembaruan);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KomoditasHiveModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
