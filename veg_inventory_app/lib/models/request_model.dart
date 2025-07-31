import 'package:cloud_firestore/cloud_firestore.dart';
import 'item_model.dart';

class RequestModel {
  final String id;
  final String shopId;
  final String date;
  final List<ItemModel> items;
  final bool submitted;
  final DateTime createdAt;

  RequestModel({
    required this.id,
    required this.shopId,
    required this.date,
    required this.items,
    required this.submitted,
    required this.createdAt,
  });

  factory RequestModel.fromMap(Map<String, dynamic> map, String id) {
    return RequestModel(
      id: id,
      shopId: map['shopId'] ?? '',
      date: map['date'] ?? '',
      items: (map['items'] as List<dynamic>?)
              ?.map((item) => ItemModel.fromMap(item))
              .toList() ??
          [],
      submitted: map['submitted'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'shopId': shopId,
      'date': date,
      'items': items.map((item) => item.toMap()).toList(),
      'submitted': submitted,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}