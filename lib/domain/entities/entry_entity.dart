/// One shop's needed quantity for one catalog item within a cycle.
/// The admin pivot grid is these rows pivoted: rows = items, columns = shops.
class EntryEntity {
  final String id; // deterministic: "<cycleId>_<shopId>_<itemId>"
  final String cycleId;
  final String itemId;
  final String itemName; // denormalized so history/prints stay stable
  final String shopId;
  final int quantity;
  final String? notes;
  final bool bought;
  final String createdBy; // member id (email)
  final DateTime createdAt;

  const EntryEntity({
    required this.id,
    required this.cycleId,
    required this.itemId,
    required this.itemName,
    required this.shopId,
    required this.quantity,
    required this.notes,
    required this.bought,
    required this.createdBy,
    required this.createdAt,
  });

  static String buildId(String cycleId, String shopId, String itemId) =>
      '${cycleId}_${shopId}_$itemId';

  Map<String, dynamic> toMap() => {
        'cycleId': cycleId,
        'itemId': itemId,
        'itemName': itemName,
        'shopId': shopId,
        'quantity': quantity,
        'notes': notes,
        'bought': bought,
        'createdBy': createdBy,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  factory EntryEntity.fromMap(String id, Map<String, dynamic> map) => EntryEntity(
        id: id,
        cycleId: map['cycleId'] as String? ?? '',
        itemId: map['itemId'] as String? ?? '',
        itemName: map['itemName'] as String? ?? '',
        shopId: map['shopId'] as String? ?? '',
        quantity: (map['quantity'] as num?)?.toInt() ?? 0,
        notes: map['notes'] as String?,
        bought: map['bought'] as bool? ?? false,
        createdBy: map['createdBy'] as String? ?? '',
        createdAt: map['createdAt'] == null
            ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
            : DateTime.parse(map['createdAt'] as String).toUtc(),
      );

  EntryEntity copyWith({int? quantity, String? notes, bool? bought}) => EntryEntity(
        id: id,
        cycleId: cycleId,
        itemId: itemId,
        itemName: itemName,
        shopId: shopId,
        quantity: quantity ?? this.quantity,
        notes: notes ?? this.notes,
        bought: bought ?? this.bought,
        createdBy: createdBy,
        createdAt: createdAt,
      );

  @override
  bool operator ==(Object other) =>
      other is EntryEntity &&
      other.id == id &&
      other.cycleId == cycleId &&
      other.itemId == itemId &&
      other.itemName == itemName &&
      other.shopId == shopId &&
      other.quantity == quantity &&
      other.notes == notes &&
      other.bought == bought &&
      other.createdBy == createdBy &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, cycleId, itemId, itemName, shopId,
      quantity, notes, bought, createdBy, createdAt);
}
