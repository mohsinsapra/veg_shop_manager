import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/missing_item.dart';
import '../../data/models/shopping_history.dart';
import '../constants/app_constants.dart';

abstract class StorageService {
  Future<void> init();
  Future<List<MissingItem>> getAllMissingItems();
  Future<void> saveMissingItem(MissingItem item);
  Future<void> deleteMissingItem(String id);
  Future<List<ShoppingHistory>> getAllShoppingHistory();
  Future<void> saveShoppingHistory(ShoppingHistory history);
  Future<void> deleteShoppingHistory(String id);
  Future<String?> getAuthData(String key);
  Future<void> setAuthData(String key, String value);
  Future<void> removeAuthData(String key);
  Future<String?> getLocale();
  Future<void> setLocale(String languageCode);
  Future<void> close();
}

class HiveStorageService implements StorageService {
  Box<MissingItem>? _missingItemsBox;
  Box<ShoppingHistory>? _historyBox;
  Box<String>? _authBox;

  @override
  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(MissingItemAdapter());
    Hive.registerAdapter(ShoppingHistoryAdapter());
    
    _missingItemsBox = await Hive.openBox<MissingItem>(AppConstants.hiveBoxMissingItems);
    _historyBox = await Hive.openBox<ShoppingHistory>(AppConstants.hiveBoxShoppingHistory);
    _authBox = await Hive.openBox<String>(AppConstants.hiveBoxAuth);
  }

  @override
  Future<List<MissingItem>> getAllMissingItems() async {
    return _missingItemsBox?.values.toList() ?? [];
  }

  @override
  Future<void> saveMissingItem(MissingItem item) async {
    await _missingItemsBox?.put(item.id, item);
  }

  @override
  Future<void> deleteMissingItem(String id) async {
    await _missingItemsBox?.delete(id);
  }

  @override
  Future<List<ShoppingHistory>> getAllShoppingHistory() async {
    return _historyBox?.values.toList() ?? [];
  }

  @override
  Future<void> saveShoppingHistory(ShoppingHistory history) async {
    await _historyBox?.put(history.id, history);
  }

  @override
  Future<void> deleteShoppingHistory(String id) async {
    await _historyBox?.delete(id);
  }

  @override
  Future<String?> getAuthData(String key) async {
    return _authBox?.get(key);
  }

  @override
  Future<void> setAuthData(String key, String value) async {
    await _authBox?.put(key, value);
  }

  @override
  Future<void> removeAuthData(String key) async {
    await _authBox?.delete(key);
  }

  @override
  Future<String?> getLocale() async {
    return _authBox?.get('locale');
  }

  @override
  Future<void> setLocale(String languageCode) async {
    await _authBox?.put('locale', languageCode);
  }

  @override
  Future<void> close() async {
    await Hive.close();
  }
}

class SharedPreferencesStorageService implements StorageService {
  SharedPreferences? _prefs;

  @override
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  @override
  Future<List<MissingItem>> getAllMissingItems() async {
    final itemsJson = _prefs?.getStringList('missing_items') ?? [];
    final items = itemsJson.map((jsonStr) {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return MissingItem(
        id: json['id'],
        itemName: json['itemName'],
        quantity: json['quantity'],
        shopId: json['shopId'],
        date: DateTime.parse(json['date']),
        notes: json['notes'],
        bought: json['bought'] ?? false,
      );
    }).toList();
    
    // Debug: Print the retrieved items count
    print('SharedPreferences: Retrieved ${items.length} items total');
    return items;
  }

  @override
  Future<void> saveMissingItem(MissingItem item) async {
    final items = await getAllMissingItems();
    
    final existingIndex = items.indexWhere((i) => i.id == item.id);
    if (existingIndex != -1) {
      items[existingIndex] = item;
    } else {
      items.add(item);
    }
    
    final itemsJson = items.map((item) => jsonEncode({
      'id': item.id,
      'itemName': item.itemName,
      'quantity': item.quantity,
      'shopId': item.shopId,
      'date': item.date.toIso8601String(),
      'notes': item.notes,
      'bought': item.bought,
    })).toList();
    
    await _prefs?.setStringList('missing_items', itemsJson);
    
    // Debug: Print the saved items count
    print('SharedPreferences: Saved ${items.length} items total');
  }

  @override
  Future<void> deleteMissingItem(String id) async {
    final items = await getAllMissingItems();
    items.removeWhere((item) => item.id == id);
    
    final itemsJson = items.map((item) => jsonEncode({
      'id': item.id,
      'itemName': item.itemName,
      'quantity': item.quantity,
      'shopId': item.shopId,
      'date': item.date.toIso8601String(),
      'notes': item.notes,
      'bought': item.bought,
    })).toList();
    
    await _prefs?.setStringList('missing_items', itemsJson);
  }

  @override
  Future<List<ShoppingHistory>> getAllShoppingHistory() async {
    final historyJson = _prefs?.getStringList('shopping_history') ?? [];
    final history = historyJson.map((jsonStr) {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final itemsJson = json['items'] as List<dynamic>;
      final items = itemsJson.map((itemJson) {
        final item = itemJson as Map<String, dynamic>;
        return MissingItem(
          id: item['id'],
          itemName: item['itemName'],
          quantity: item['quantity'],
          shopId: item['shopId'],
          date: DateTime.parse(item['date']),
          notes: item['notes'],
          bought: item['bought'] ?? false,
        );
      }).toList();
      
      return ShoppingHistory(
        id: json['id'],
        completedDate: DateTime.parse(json['completedDate']),
        originalDate: DateTime.parse(json['originalDate']),
        items: items,
        totalItems: json['totalItems'],
        totalQuantity: json['totalQuantity'],
      );
    }).toList();
    
    return history;
  }

  @override
  Future<void> saveShoppingHistory(ShoppingHistory history) async {
    final allHistory = await getAllShoppingHistory();
    
    final existingIndex = allHistory.indexWhere((h) => h.id == history.id);
    if (existingIndex != -1) {
      allHistory[existingIndex] = history;
    } else {
      allHistory.add(history);
    }
    
    final historyJson = allHistory.map((history) => jsonEncode({
      'id': history.id,
      'completedDate': history.completedDate.toIso8601String(),
      'originalDate': history.originalDate.toIso8601String(),
      'totalItems': history.totalItems,
      'totalQuantity': history.totalQuantity,
      'items': history.items.map((item) => {
        'id': item.id,
        'itemName': item.itemName,
        'quantity': item.quantity,
        'shopId': item.shopId,
        'date': item.date.toIso8601String(),
        'notes': item.notes,
        'bought': item.bought,
      }).toList(),
    })).toList();
    
    await _prefs?.setStringList('shopping_history', historyJson);
  }

  @override
  Future<void> deleteShoppingHistory(String id) async {
    final allHistory = await getAllShoppingHistory();
    allHistory.removeWhere((history) => history.id == id);
    
    final historyJson = allHistory.map((history) => jsonEncode({
      'id': history.id,
      'completedDate': history.completedDate.toIso8601String(),
      'originalDate': history.originalDate.toIso8601String(),
      'totalItems': history.totalItems,
      'totalQuantity': history.totalQuantity,
      'items': history.items.map((item) => {
        'id': item.id,
        'itemName': item.itemName,
        'quantity': item.quantity,
        'shopId': item.shopId,
        'date': item.date.toIso8601String(),
        'notes': item.notes,
        'bought': item.bought,
      }).toList(),
    })).toList();
    
    await _prefs?.setStringList('shopping_history', historyJson);
  }

  @override
  Future<String?> getAuthData(String key) async {
    return _prefs?.getString('auth_$key');
  }

  @override
  Future<void> setAuthData(String key, String value) async {
    await _prefs?.setString('auth_$key', value);
  }

  @override
  Future<void> removeAuthData(String key) async {
    await _prefs?.remove('auth_$key');
  }

  @override
  Future<String?> getLocale() async {
    return _prefs?.getString('locale');
  }

  @override
  Future<void> setLocale(String languageCode) async {
    await _prefs?.setString('locale', languageCode);
  }

  @override
  Future<void> close() async {
    // SharedPreferences doesn't need explicit closing
  }
}

class StorageServiceFactory {
  static StorageService? _instance;
  
  static StorageService get instance {
    _instance ??= _createInstance();
    return _instance!;
  }
  
  static StorageService _createInstance() {
    if (kIsWeb) {
      return SharedPreferencesStorageService();
    } else {
      return HiveStorageService();
    }
  }
  
  static StorageService create() => instance;
}