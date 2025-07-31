import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/request_model.dart';
import '../models/shop_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveRequest(RequestModel request) async {
    await _firestore.collection('requests').doc(request.id).set(request.toMap());
  }

  Future<RequestModel?> getTodayRequest(String shopId) async {
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    QuerySnapshot query = await _firestore
        .collection('requests')
        .where('shopId', isEqualTo: shopId)
        .where('date', isEqualTo: today)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return RequestModel.fromMap(
        query.docs.first.data() as Map<String, dynamic>,
        query.docs.first.id,
      );
    }
    return null;
  }

  Stream<List<RequestModel>> getShopRequests(String shopId) {
    return _firestore
        .collection('requests')
        .where('shopId', isEqualTo: shopId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RequestModel.fromMap(
                doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Stream<List<RequestModel>> getAllTodayRequests() {
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    return _firestore
        .collection('requests')
        .where('date', isEqualTo: today)
        .where('submitted', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RequestModel.fromMap(
                doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Future<ShopModel?> getShop(String shopId) async {
    DocumentSnapshot doc = await _firestore.collection('shops').doc(shopId).get();
    if (doc.exists) {
      return ShopModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  Future<List<ShopModel>> getAllShops() async {
    QuerySnapshot query = await _firestore.collection('shops').get();
    return query.docs
        .map((doc) => ShopModel.fromMap(
            doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }
}