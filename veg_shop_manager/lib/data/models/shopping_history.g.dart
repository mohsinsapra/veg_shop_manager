// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shopping_history.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ShoppingHistoryAdapter extends TypeAdapter<ShoppingHistory> {
  @override
  final int typeId = 1;

  @override
  ShoppingHistory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ShoppingHistory(
      id: fields[0] as String,
      completedDate: fields[1] as DateTime,
      originalDate: fields[2] as DateTime,
      items: (fields[3] as List).cast<MissingItem>(),
      totalItems: fields[4] as int,
      totalQuantity: fields[5] as int,
    );
  }

  @override
  void write(BinaryWriter writer, ShoppingHistory obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.completedDate)
      ..writeByte(2)
      ..write(obj.originalDate)
      ..writeByte(3)
      ..write(obj.items)
      ..writeByte(4)
      ..write(obj.totalItems)
      ..writeByte(5)
      ..write(obj.totalQuantity);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShoppingHistoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
