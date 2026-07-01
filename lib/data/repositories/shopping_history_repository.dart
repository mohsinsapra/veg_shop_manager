import '../models/shopping_history.dart';
import '../datasources/local/shopping_history_local_ds.dart';

class ShoppingHistoryRepository {
  final ShoppingHistoryLocalDataSource _localDataSource;

  ShoppingHistoryRepository(this._localDataSource);

  Future<List<ShoppingHistory>> getAllShoppingHistory() {
    return _localDataSource.getAllShoppingHistory();
  }

  Future<void> saveShoppingHistory(ShoppingHistory history) {
    return _localDataSource.saveShoppingHistory(history);
  }

  Future<void> deleteShoppingHistory(String id) {
    return _localDataSource.deleteShoppingHistory(id);
  }
}