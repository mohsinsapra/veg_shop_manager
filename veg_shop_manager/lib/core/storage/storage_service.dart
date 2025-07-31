import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/missing_item.dart';
import '../constants/app_constants.dart';

abstract class StorageService {
  Future<void> init();
  Future<List<MissingItem>> getAllMissingItems();
  Future<void> saveMissingItem(MissingItem item);
  Future<void> deleteMissingItem(String id);
  Future<String?> getAuthData(String key);
  Future<void> setAuthData(String key, String value);
  Future<void> removeAuthData(String key);
  Future<void> close();
}

class HiveStorageService implements StorageService {
  Box<MissingItem>? _missingItemsBox;
  Box<String>? _authBox;

  @override
  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(MissingItemAdapter());
    
    _missingItemsBox = await Hive.openBox<MissingItem>(AppConstants.hiveBoxMissingItems);
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