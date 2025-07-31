import 'package:uuid/uuid.dart';
import '../../data/models/missing_item.dart';
import '../../data/repositories/missing_item_repo.dart';
import '../entities/missing_item_entity.dart';

class SubmitMissingItemUseCase {
  final MissingItemRepository _repository;
  final Uuid _uuid = const Uuid();

  SubmitMissingItemUseCase(this._repository);

  Future<void> execute({
    required String itemName,
    required int quantity,
    required String shopId,
    String? notes,
    String? id,
  }) async {
    final missingItem = MissingItem(
      id: id ?? _uuid.v4(),
      itemName: itemName.trim(),
      quantity: quantity,
      shopId: shopId,
      date: DateTime.now(),
      notes: notes?.trim(),
    );

    if (id != null) {
      await _repository.updateMissingItem(missingItem);
    } else {
      await _repository.addMissingItem(missingItem);
    }
  }
}

class GetTodaysMissingItemsUseCase {
  final MissingItemRepository _repository;

  GetTodaysMissingItemsUseCase(this._repository);

  Future<List<MissingItemEntity>> execute([String? shopId]) async {
    final items = shopId != null
        ? await _repository.getTodaysMissingItemsByShop(shopId)
        : await _repository.getTodaysMissingItems();

    return items
        .map((item) => MissingItemEntity(
              id: item.id,
              itemName: item.itemName,
              quantity: item.quantity,
              shopId: item.shopId,
              date: item.date,
              notes: item.notes,
            ))
        .toList();
  }
}

class DeleteMissingItemUseCase {
  final MissingItemRepository _repository;

  DeleteMissingItemUseCase(this._repository);

  Future<void> execute(String id) async {
    await _repository.deleteMissingItem(id);
  }
}

class GetGroupedMissingItemsUseCase {
  final MissingItemRepository _repository;

  GetGroupedMissingItemsUseCase(this._repository);

  Future<Map<String, List<MissingItemEntity>>> execute() async {
    final grouped = await _repository.getTodaysItemsGroupedByItem();
    
    return grouped.map((key, items) => MapEntry(
          key,
          items
              .map((item) => MissingItemEntity(
                    id: item.id,
                    itemName: item.itemName,
                    quantity: item.quantity,
                    shopId: item.shopId,
                    date: item.date,
                    notes: item.notes,
                  ))
              .toList(),
        ));
  }
}