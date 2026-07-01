class ShopEntity {
  final String id;
  final String name;
  final String code;
  final int sortOrder;
  final bool active;

  const ShopEntity({
    required this.id,
    required this.name,
    required this.code,
    required this.sortOrder,
    required this.active,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'code': code,
        'sortOrder': sortOrder,
        'active': active,
      };

  factory ShopEntity.fromMap(String id, Map<String, dynamic> map) => ShopEntity(
        id: id,
        name: map['name'] as String? ?? '',
        code: map['code'] as String? ?? '',
        sortOrder: (map['sortOrder'] as num?)?.toInt() ?? 0,
        active: map['active'] as bool? ?? true,
      );

  ShopEntity copyWith({String? name, String? code, int? sortOrder, bool? active}) =>
      ShopEntity(
        id: id,
        name: name ?? this.name,
        code: code ?? this.code,
        sortOrder: sortOrder ?? this.sortOrder,
        active: active ?? this.active,
      );

  @override
  bool operator ==(Object other) =>
      other is ShopEntity &&
      other.id == id &&
      other.name == name &&
      other.code == code &&
      other.sortOrder == sortOrder &&
      other.active == active;

  @override
  int get hashCode => Object.hash(id, name, code, sortOrder, active);
}
