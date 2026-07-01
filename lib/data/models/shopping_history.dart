import 'package:hive/hive.dart';
import 'missing_item.dart';

part 'shopping_history.g.dart';

@HiveType(typeId: 1)
class ShoppingHistory extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime completedDate;

  @HiveField(2)
  final DateTime originalDate;

  @HiveField(3)
  final List<MissingItem> items;

  @HiveField(4)
  final int totalItems;

  @HiveField(5)
  final int totalQuantity;

  ShoppingHistory({
    required this.id,
    required this.completedDate,
    required this.originalDate,
    required this.items,
    required this.totalItems,
    required this.totalQuantity,
  });

  ShoppingHistory copyWith({
    String? id,
    DateTime? completedDate,
    DateTime? originalDate,
    List<MissingItem>? items,
    int? totalItems,
    int? totalQuantity,
  }) {
    return ShoppingHistory(
      id: id ?? this.id,
      completedDate: completedDate ?? this.completedDate,
      originalDate: originalDate ?? this.originalDate,
      items: items ?? this.items,
      totalItems: totalItems ?? this.totalItems,
      totalQuantity: totalQuantity ?? this.totalQuantity,
    );
  }
}