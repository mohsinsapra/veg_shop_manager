import 'package:hive/hive.dart';

part 'missing_item.g.dart';

@HiveType(typeId: 0)
class MissingItem extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String itemName;

  @HiveField(2)
  final int quantity;

  @HiveField(3)
  final String shopId;

  @HiveField(4)
  final DateTime date;

  @HiveField(5)
  final String? notes;

  @HiveField(6)
  final bool bought;

  MissingItem({
    required this.id,
    required this.itemName,
    required this.quantity,
    required this.shopId,
    required this.date,
    this.notes,
    this.bought = false,
  });

  MissingItem copyWith({
    String? id,
    String? itemName,
    int? quantity,
    String? shopId,
    DateTime? date,
    String? notes,
    bool? bought,
  }) {
    return MissingItem(
      id: id ?? this.id,
      itemName: itemName ?? this.itemName,
      quantity: quantity ?? this.quantity,
      shopId: shopId ?? this.shopId,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      bought: bought ?? this.bought,
    );
  }
}