import '../models/missing_item.dart';
import '../datasources/local/missing_item_local_ds.dart';

class MissingItemRepository {
  final MissingItemLocalDataSource _localDataSource;

  MissingItemRepository(this._localDataSource);

  Future<List<MissingItem>> getAllMissingItems() {
    return _localDataSource.getAllMissingItems();
  }

  Future<List<MissingItem>> getMissingItemsByShop(String shopId) {
    return _localDataSource.getMissingItemsByShop(shopId);
  }

  Future<List<MissingItem>> getTodaysMissingItems() {
    return _localDataSource.getTodaysMissingItems();
  }

  Future<List<MissingItem>> getTodaysMissingItemsByShop(String shopId) {
    return _localDataSource.getTodaysMissingItemsByShop(shopId);
  }

  Future<void> addMissingItem(MissingItem item) {
    return _localDataSource.addMissingItem(item);
  }

  Future<void> updateMissingItem(MissingItem item) {
    return _localDataSource.updateMissingItem(item);
  }

  Future<void> deleteMissingItem(String id) {
    return _localDataSource.deleteMissingItem(id);
  }

  Future<void> clearTodaysItems(String shopId) {
    return _localDataSource.clearTodaysItems(shopId);
  }

  Future<Map<String, List<MissingItem>>> getTodaysItemsGroupedByItem() {
    return _localDataSource.getTodaysItemsGroupedByItem();
  }
}