class CatalogItemEntity {
  final String id;
  final String name;
  final String category;
  final int sortOrder;
  final bool active;

  const CatalogItemEntity({
    required this.id,
    required this.name,
    required this.category,
    required this.sortOrder,
    required this.active,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'category': category,
        'sortOrder': sortOrder,
        'active': active,
      };

  factory CatalogItemEntity.fromMap(String id, Map<String, dynamic> map) =>
      CatalogItemEntity(
        id: id,
        name: map['name'] as String? ?? '',
        category: map['category'] as String? ?? '',
        sortOrder: (map['sortOrder'] as num?)?.toInt() ?? 0,
        active: map['active'] as bool? ?? true,
      );

  CatalogItemEntity copyWith({String? name, String? category, int? sortOrder, bool? active}) =>
      CatalogItemEntity(
        id: id,
        name: name ?? this.name,
        category: category ?? this.category,
        sortOrder: sortOrder ?? this.sortOrder,
        active: active ?? this.active,
      );

  @override
  bool operator ==(Object other) =>
      other is CatalogItemEntity &&
      other.id == id &&
      other.name == name &&
      other.category == category &&
      other.sortOrder == sortOrder &&
      other.active == active;

  @override
  int get hashCode => Object.hash(id, name, category, sortOrder, active);
}
