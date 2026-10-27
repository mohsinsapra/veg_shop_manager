import '../../core/utils/qty_format.dart';

/// One shop's needed quantity for one catalog item within a cycle.
/// The admin pivot grid is these rows pivoted: rows = items, columns = shops.
class EntryEntity {
  final String id; // deterministic: "<cycleId>_<shopId>_<itemId>[_<size>]"
  final String cycleId;
  final String itemId;
  final String itemName; // denormalized so history/prints stay stable
  final String shopId;
  final double quantity;
  final String? notes;
  final bool bought;
  final String createdBy; // member id (email)
  final DateTime createdAt;

  /// The pack size this entry is for (e.g. 5 for a 5kg box); null for a plain
  /// (unsized) item. A shop can hold entries for several sizes of the same
  /// item at once — each size is a separate doc, see [buildId].
  final double? packSize;

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
    this.packSize,
  });

  /// Plain items keep the exact previous id scheme; a sized entry appends
  /// the formatted size so a shop can order several sizes of one item within
  /// the same cycle (e.g. both 5kg and 10kg boxes of carrots).
  static String buildId(String cycleId, String shopId, String itemId,
          {double? packSize}) =>
      '${cycleId}_${shopId}_${itemSizeKey(itemId, packSize)}';

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
        'packSize': packSize,
      };

  factory EntryEntity.fromMap(String id, Map<String, dynamic> map) => EntryEntity(
        id: id,
        cycleId: map['cycleId'] as String? ?? '',
        itemId: map['itemId'] as String? ?? '',
        itemName: map['itemName'] as String? ?? '',
        shopId: map['shopId'] as String? ?? '',
        quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
        notes: map['notes'] as String?,
        bought: map['bought'] as bool? ?? false,
        createdBy: map['createdBy'] as String? ?? '',
        createdAt: map['createdAt'] == null
            ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
            : DateTime.parse(map['createdAt'] as String).toUtc(),
        packSize: (map['packSize'] as num?)?.toDouble(),
      );

  EntryEntity copyWith({double? quantity, String? notes, bool? bought}) => EntryEntity(
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
        packSize: packSize,
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
      other.createdAt == createdAt &&
      other.packSize == packSize;

  @override
  int get hashCode => Object.hash(id, cycleId, itemId, itemName, shopId,
      quantity, notes, bought, createdBy, createdAt, packSize);
}
