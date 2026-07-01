// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'missing_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MissingItemAdapter extends TypeAdapter<MissingItem> {
  @override
  final int typeId = 0;

  @override
  MissingItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MissingItem(
      id: fields[0] as String,
      itemName: fields[1] as String,
      quantity: fields[2] as int,
      shopId: fields[3] as String,
      date: fields[4] as DateTime,
      notes: fields[5] as String?,
      bought: fields[6] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, MissingItem obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.itemName)
      ..writeByte(2)
      ..write(obj.quantity)
      ..writeByte(3)
      ..write(obj.shopId)
      ..writeByte(4)
      ..write(obj.date)
      ..writeByte(5)
      ..write(obj.notes)
      ..writeByte(6)
      ..write(obj.bought);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MissingItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
