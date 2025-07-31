class MissingItemEntity {
  final String id;
  final String itemName;
  final int quantity;
  final String shopId;
  final DateTime date;
  final String? notes;
  final bool bought;

  const MissingItemEntity({
    required this.id,
    required this.itemName,
    required this.quantity,
    required this.shopId,
    required this.date,
    this.notes,
    this.bought = false,
  });

  MissingItemEntity copyWith({
    String? id,
    String? itemName,
    int? quantity,
    String? shopId,
    DateTime? date,
    String? notes,
    bool? bought,
  }) {
    return MissingItemEntity(
      id: id ?? this.id,
      itemName: itemName ?? this.itemName,
      quantity: quantity ?? this.quantity,
      shopId: shopId ?? this.shopId,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      bought: bought ?? this.bought,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MissingItemEntity &&
        other.id == id &&
        other.itemName == itemName &&
        other.quantity == quantity &&
        other.shopId == shopId &&
        other.date == date &&
        other.notes == notes &&
        other.bought == bought;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        itemName.hashCode ^
        quantity.hashCode ^
        shopId.hashCode ^
        date.hashCode ^
        notes.hashCode ^
        bought.hashCode;
  }
}