// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'petani_hive_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PetaniHiveModelAdapter extends TypeAdapter<PetaniHiveModel> {
  @override
  final int typeId = 1;

  @override
  PetaniHiveModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PetaniHiveModel(
      id: fields[0] as String,
      namaPetani: fields[1] as String,
      desa: fields[2] as String,
      pengepulId: fields[3] as String,
      sisaHutangKasbon: fields[4] as double,
      waktuDibuat: fields[5] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, PetaniHiveModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.namaPetani)
      ..writeByte(2)
      ..write(obj.desa)
      ..writeByte(3)
      ..write(obj.pengepulId)
      ..writeByte(4)
      ..write(obj.sisaHutangKasbon)
      ..writeByte(5)
      ..write(obj.waktuDibuat);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PetaniHiveModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
