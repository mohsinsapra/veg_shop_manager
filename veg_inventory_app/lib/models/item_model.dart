class ItemModel {
  final String name;
  final double quantity;
  final String unit;
  final String note;

  ItemModel({
    required this.name,
    required this.quantity,
    required this.unit,
    this.note = '',
  });

  factory ItemModel.fromMap(Map<String, dynamic> map) {
    return ItemModel(
      name: map['name'] ?? '',
      quantity: (map['quantity'] ?? 0).toDouble(),
      unit: map['unit'] ?? 'kg',
      note: map['note'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'note': note,
    };
  }
}