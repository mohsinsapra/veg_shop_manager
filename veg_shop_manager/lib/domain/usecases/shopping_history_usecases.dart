import 'package:uuid/uuid.dart';
import '../../data/models/shopping_history.dart';
import '../../data/repositories/shopping_history_repository.dart';
import '../../data/repositories/missing_item_repo.dart';
import '../entities/shopping_history_entity.dart';
import '../entities/missing_item_entity.dart';
import '../../core/utils/date_utils.dart';

class CompleteShoppingListUseCase {
  final ShoppingHistoryRepository _historyRepository;
  final MissingItemRepository _missingItemRepository;
  final Uuid _uuid = const Uuid();

  CompleteShoppingListUseCase(this._historyRepository, this._missingItemRepository);

  Future<void> execute() async {
    final today = AppDateUtils.today;
    final todaysItems = await _missingItemRepository.getTodaysMissingItems();
    
    if (todaysItems.isEmpty) {
      throw Exception('No items to complete');
    }

    // Create shopping history entry
    final history = ShoppingHistory(
      id: _uuid.v4(),
      completedDate: DateTime.now(),
      originalDate: today,
      items: todaysItems,
      totalItems: todaysItems.map((item) => item.itemName).toSet().length,
      totalQuantity: todaysItems.fold(0, (sum, item) => sum + item.quantity),
    );

    // Save to history
    await _historyRepository.saveShoppingHistory(history);

    // Clear today's items
    for (final item in todaysItems) {
      await _missingItemRepository.deleteMissingItem(item.id);
    }
  }
}

class GetShoppingHistoryUseCase {
  final ShoppingHistoryRepository _repository;

  GetShoppingHistoryUseCase(this._repository);

  Future<List<ShoppingHistoryEntity>> execute() async {
    final histories = await _repository.getAllShoppingHistory();
    
    // Sort by completion date descending (newest first)
    histories.sort((a, b) => b.completedDate.compareTo(a.completedDate));
    
    return histories
        .map((history) => ShoppingHistoryEntity(
              id: history.id,
              completedDate: history.completedDate,
              originalDate: history.originalDate,
              totalItems: history.totalItems,
              totalQuantity: history.totalQuantity,
              items: history.items
                  .map((item) => MissingItemEntity(
                        id: item.id,
                        itemName: item.itemName,
                        quantity: item.quantity,
                        shopId: item.shopId,
                        date: item.date,
                        notes: item.notes,
                        bought: item.bought,
                      ))
                  .toList(),
            ))
        .toList();
  }
}

class DeleteShoppingHistoryUseCase {
  final ShoppingHistoryRepository _repository;

  DeleteShoppingHistoryUseCase(this._repository);

  Future<void> execute(String id) async {
    await _repository.deleteShoppingHistory(id);
  }
}