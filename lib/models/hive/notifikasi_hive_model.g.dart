// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notifikasi_hive_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NotifikasiHiveModelAdapter extends TypeAdapter<NotifikasiHiveModel> {
  @override
  final int typeId = 4;

  @override
  NotifikasiHiveModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NotifikasiHiveModel(
      id: fields[0] as String,
      judul: fields[1] as String,
      pesan: fields[2] as String,
      waktu: fields[3] as DateTime,
      isRead: fields[4] as bool,
      tipe: fields[5] as String,
    );
  }

  @override
  void write(BinaryWriter writer, NotifikasiHiveModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.judul)
      ..writeByte(2)
      ..write(obj.pesan)
      ..writeByte(3)
      ..write(obj.waktu)
      ..writeByte(4)
      ..write(obj.isRead)
      ..writeByte(5)
      ..write(obj.tipe);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotifikasiHiveModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
