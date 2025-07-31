import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/request_model.dart';
import '../models/item_model.dart';
import '../services/firestore_service.dart';

class RequestProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  RequestModel? _currentRequest;
  List<ItemModel> _currentItems = [];
  bool _isLoading = false;

  RequestModel? get currentRequest => _currentRequest;
  List<ItemModel> get currentItems => _currentItems;
  bool get isLoading => _isLoading;

  Future<void> loadTodayRequest(String shopId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _currentRequest = await _firestoreService.getTodayRequest(shopId);
      if (_currentRequest != null) {
        _currentItems = List.from(_currentRequest!.items);
      } else {
        _currentItems = [];
      }
    } catch (e) {
      _currentItems = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  void addItem(ItemModel item) {
    _currentItems.add(item);
    notifyListeners();
  }

  void removeItem(int index) {
    if (index >= 0 && index < _currentItems.length) {
      _currentItems.removeAt(index);
      notifyListeners();
    }
  }

  void updateItem(int index, ItemModel item) {
    if (index >= 0 && index < _currentItems.length) {
      _currentItems[index] = item;
      notifyListeners();
    }
  }

  Future<void> saveRequest(String shopId, {bool submit = false}) async {
    _isLoading = true;
    notifyListeners();

    try {
      String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      String requestId = '${shopId}_$today';

      RequestModel request = RequestModel(
        id: requestId,
        shopId: shopId,
        date: today,
        items: _currentItems,
        submitted: submit,
        createdAt: DateTime.now(),
      );

      await _firestoreService.saveRequest(request);
      _currentRequest = request;
    } catch (e) {
      rethrow;
    }

    _isLoading = false;
    notifyListeners();
  }

  void clearItems() {
    _currentItems.clear();
    notifyListeners();
  }
}