class ShopModel {
  final String id;
  final String name;
  final String location;

  ShopModel({
    required this.id,
    required this.name,
    required this.location,
  });

  factory ShopModel.fromMap(Map<String, dynamic> map, String id) {
    return ShopModel(
      id: id,
      name: map['name'] ?? '',
      location: map['location'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'location': location,
    };
  }
}