class CatalogItemEntity {
  final String id;
  final String name;
  final String category;
  final int sortOrder;
  final bool active;

  /// Hotlinked product photo (e.g. Wikimedia thumbnail); empty when none.
  final String imageUrl;

  /// Free-text unit label (e.g. 'kg', 'caja', 'und'); empty when not set.
  final String unit;

  /// Predefined pack/box sizes this item can be ordered in (e.g. [5, 10] kg).
  /// Empty means the item is ordered as a plain quantity, unchanged from
  /// before this field existed.
  final List<double> packSizes;

  const CatalogItemEntity({
    required this.id,
    required this.name,
    required this.category,
    required this.sortOrder,
    required this.active,
    this.imageUrl = '',
    this.unit = '',
    this.packSizes = const [],
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'category': category,
        'sortOrder': sortOrder,
        'active': active,
        'imageUrl': imageUrl,
        'unit': unit,
        'packSizes': packSizes,
      };

  factory CatalogItemEntity.fromMap(String id, Map<String, dynamic> map) =>
      CatalogItemEntity(
        id: id,
        name: map['name'] as String? ?? '',
        category: map['category'] as String? ?? '',
        sortOrder: (map['sortOrder'] as num?)?.toInt() ?? 0,
        active: map['active'] as bool? ?? true,
        imageUrl: map['imageUrl'] as String? ?? '',
        unit: map['unit'] as String? ?? '',
        packSizes: (map['packSizes'] as List<dynamic>?)
                ?.map((v) => (v as num).toDouble())
                .toList() ??
            const [],
      );

  CatalogItemEntity copyWith(
          {String? name,
          String? category,
          int? sortOrder,
          bool? active,
          String? imageUrl,
          String? unit,
          List<double>? packSizes}) =>
      CatalogItemEntity(
        id: id,
        name: name ?? this.name,
        category: category ?? this.category,
        sortOrder: sortOrder ?? this.sortOrder,
        active: active ?? this.active,
        imageUrl: imageUrl ?? this.imageUrl,
        unit: unit ?? this.unit,
        packSizes: packSizes ?? this.packSizes,
      );

  @override
  bool operator ==(Object other) =>
      other is CatalogItemEntity &&
      other.id == id &&
      other.name == name &&
      other.category == category &&
      other.sortOrder == sortOrder &&
      other.active == active &&
      other.imageUrl == imageUrl &&
      other.unit == unit &&
      _listEquals(other.packSizes, packSizes);

  static bool _listEquals(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(id, name, category, sortOrder, active,
      imageUrl, unit, Object.hashAll(packSizes));
}
