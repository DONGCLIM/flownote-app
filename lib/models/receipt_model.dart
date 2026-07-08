import 'package:hive/hive.dart';

part 'receipt_model.g.dart';

@HiveType(typeId: 0)
class ReceiptModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  DateTime date;

  @HiveField(2)
  String storeName;

  @HiveField(3)
  List<FlowerItem> items;

  @HiveField(4)
  double totalAmount;

  @HiveField(5)
  String? imagePath;

  @HiveField(6)
  String rawOcrText;

  @HiveField(7)
  DateTime createdAt;

  @HiveField(8)
  bool isManuallyEdited;

  ReceiptModel({
    required this.id,
    required this.date,
    required this.storeName,
    required this.items,
    required this.totalAmount,
    this.imagePath,
    required this.rawOcrText,
    required this.createdAt,
    this.isManuallyEdited = false,
  });

  ReceiptModel copyWith({
    String? id,
    DateTime? date,
    String? storeName,
    List<FlowerItem>? items,
    double? totalAmount,
    String? imagePath,
    String? rawOcrText,
    DateTime? createdAt,
    bool? isManuallyEdited,
  }) {
    return ReceiptModel(
      id: id ?? this.id,
      date: date ?? this.date,
      storeName: storeName ?? this.storeName,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      imagePath: imagePath ?? this.imagePath,
      rawOcrText: rawOcrText ?? this.rawOcrText,
      createdAt: createdAt ?? this.createdAt,
      isManuallyEdited: isManuallyEdited ?? this.isManuallyEdited,
    );
  }
}

@HiveType(typeId: 1)
class FlowerItem extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  int quantity;

  @HiveField(2)
  double unitPrice;

  @HiveField(3)
  String unit; // stems, bunches, pots

  @HiveField(4)
  String? color;

  FlowerItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.unit,
    this.color,
  });

  double get totalPrice => quantity * unitPrice;
}
