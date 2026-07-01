import '../../models/missing_item.dart';
import '../../../core/storage/storage_service.dart';
import '../../../core/utils/date_utils.dart';

class MissingItemLocalDataSource {
  final StorageService _storageService;

  MissingItemLocalDataSource(this._storageService);

  Future<List<MissingItem>> getAllMissingItems() async {
    return await _storageService.getAllMissingItems();
  }

  Future<List<MissingItem>> getMissingItemsByShop(String shopId) async {
    final allItems = await _storageService.getAllMissingItems();
    return allItems.where((item) => item.shopId == shopId).toList();
  }

  Future<List<MissingItem>> getTodaysMissingItems() async {
    final today = AppDateUtils.today;
    final allItems = await _storageService.getAllMissingItems();
    final todaysItems = allItems
        .where((item) => AppDateUtils.isSameDay(item.date, today))
        .toList();
    
    // Debug: Print date filtering info
    print('Date filtering: Today = ${AppDateUtils.formatDate(today)}');
    print('Date filtering: All items = ${allItems.length}');
    print('Date filtering: Today\'s items = ${todaysItems.length}');
    for (final item in allItems) {
      print('Item: ${item.itemName} on ${AppDateUtils.formatDate(item.date)} (same day: ${AppDateUtils.isSameDay(item.date, today)})');
    }
    
    return todaysItems;
  }

  Future<List<MissingItem>> getTodaysMissingItemsByShop(String shopId) async {
    final today = AppDateUtils.today;
    final allItems = await _storageService.getAllMissingItems();
    return allItems
        .where((item) => 
            item.shopId == shopId && 
            AppDateUtils.isSameDay(item.date, today))
        .toList();
  }

  Future<void> addMissingItem(MissingItem item) async {
    await _storageService.saveMissingItem(item);
  }

  Future<void> updateMissingItem(MissingItem item) async {
    await _storageService.saveMissingItem(item);
  }

  Future<void> deleteMissingItem(String id) async {
    await _storageService.deleteMissingItem(id);
  }

  Future<void> clearTodaysItems(String shopId) async {
    final today = AppDateUtils.today;
    final allItems = await _storageService.getAllMissingItems();
    final itemsToDelete = allItems
        .where((item) => 
            item.shopId == shopId && 
            AppDateUtils.isSameDay(item.date, today))
        .toList();
    
    for (final item in itemsToDelete) {
      await _storageService.deleteMissingItem(item.id);
    }
  }

  Future<Map<String, List<MissingItem>>> getTodaysItemsGroupedByItem() async {
    final todaysItems = await getTodaysMissingItems();
    final Map<String, List<MissingItem>> grouped = {};
    
    for (final item in todaysItems) {
      if (grouped[item.itemName] == null) {
        grouped[item.itemName] = [];
      }
      grouped[item.itemName]!.add(item);
    }
    
    return grouped;
  }
}