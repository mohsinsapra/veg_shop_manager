import '../../models/shopping_history.dart';
import '../../../core/storage/storage_service.dart';

class ShoppingHistoryLocalDataSource {
  final StorageService _storageService;

  ShoppingHistoryLocalDataSource(this._storageService);

  Future<List<ShoppingHistory>> getAllShoppingHistory() async {
    return await _storageService.getAllShoppingHistory();
  }

  Future<void> saveShoppingHistory(ShoppingHistory history) async {
    await _storageService.saveShoppingHistory(history);
  }

  Future<void> deleteShoppingHistory(String id) async {
    await _storageService.deleteShoppingHistory(id);
  }
}