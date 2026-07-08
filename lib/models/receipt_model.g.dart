// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'receipt_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ReceiptModelAdapter extends TypeAdapter<ReceiptModel> {
  @override
  final int typeId = 0;

  @override
  ReceiptModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ReceiptModel(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      storeName: fields[2] as String,
      items: (fields[3] as List).cast<FlowerItem>(),
      totalAmount: fields[4] as double,
      imagePath: fields[5] as String?,
      rawOcrText: fields[6] as String,
      createdAt: fields[7] as DateTime,
      isManuallyEdited: fields[8] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ReceiptModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.storeName)
      ..writeByte(3)
      ..write(obj.items)
      ..writeByte(4)
      ..write(obj.totalAmount)
      ..writeByte(5)
      ..write(obj.imagePath)
      ..writeByte(6)
      ..write(obj.rawOcrText)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.isManuallyEdited);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReceiptModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FlowerItemAdapter extends TypeAdapter<FlowerItem> {
  @override
  final int typeId = 1;

  @override
  FlowerItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FlowerItem(
      name: fields[0] as String,
      quantity: fields[1] as int,
      unitPrice: fields[2] as double,
      unit: fields[3] as String,
      color: fields[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, FlowerItem obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.quantity)
      ..writeByte(2)
      ..write(obj.unitPrice)
      ..writeByte(3)
      ..write(obj.unit)
      ..writeByte(4)
      ..write(obj.color);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FlowerItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
