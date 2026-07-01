import 'missing_item_entity.dart';

class ShoppingHistoryEntity {
  final String id;
  final DateTime completedDate;
  final DateTime originalDate;
  final List<MissingItemEntity> items;
  final int totalItems;
  final int totalQuantity;

  const ShoppingHistoryEntity({
    required this.id,
    required this.completedDate,
    required this.originalDate,
    required this.items,
    required this.totalItems,
    required this.totalQuantity,
  });

  ShoppingHistoryEntity copyWith({
    String? id,
    DateTime? completedDate,
    DateTime? originalDate,
    List<MissingItemEntity>? items,
    int? totalItems,
    int? totalQuantity,
  }) {
    return ShoppingHistoryEntity(
      id: id ?? this.id,
      completedDate: completedDate ?? this.completedDate,
      originalDate: originalDate ?? this.originalDate,
      items: items ?? this.items,
      totalItems: totalItems ?? this.totalItems,
      totalQuantity: totalQuantity ?? this.totalQuantity,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ShoppingHistoryEntity &&
        other.id == id &&
        other.completedDate == completedDate &&
        other.originalDate == originalDate &&
        other.totalItems == totalItems &&
        other.totalQuantity == totalQuantity;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        completedDate.hashCode ^
        originalDate.hashCode ^
        totalItems.hashCode ^
        totalQuantity.hashCode;
  }
}