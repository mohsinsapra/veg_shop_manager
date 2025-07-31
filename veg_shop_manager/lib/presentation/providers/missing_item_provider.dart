import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/local/missing_item_local_ds.dart';
import '../../data/repositories/missing_item_repo.dart';
import '../../domain/entities/missing_item_entity.dart';
import '../../domain/usecases/submit_missing_item.dart';
import 'auth_provider.dart';

final missingItemLocalDataSourceProvider = Provider<MissingItemLocalDataSource>((ref) {
  return MissingItemLocalDataSource(ref.watch(storageServiceProvider));
});

final missingItemRepositoryProvider = Provider<MissingItemRepository>((ref) {
  return MissingItemRepository(ref.watch(missingItemLocalDataSourceProvider));
});

final submitMissingItemUseCaseProvider = Provider<SubmitMissingItemUseCase>((ref) {
  return SubmitMissingItemUseCase(ref.watch(missingItemRepositoryProvider));
});

final getTodaysMissingItemsUseCaseProvider = Provider<GetTodaysMissingItemsUseCase>((ref) {
  return GetTodaysMissingItemsUseCase(ref.watch(missingItemRepositoryProvider));
});

final deleteMissingItemUseCaseProvider = Provider<DeleteMissingItemUseCase>((ref) {
  return DeleteMissingItemUseCase(ref.watch(missingItemRepositoryProvider));
});

final getGroupedMissingItemsUseCaseProvider = Provider<GetGroupedMissingItemsUseCase>((ref) {
  return GetGroupedMissingItemsUseCase(ref.watch(missingItemRepositoryProvider));
});

final shopMissingItemsProvider = FutureProvider.family<List<MissingItemEntity>, String>((ref, shopId) async {
  final useCase = ref.watch(getTodaysMissingItemsUseCaseProvider);
  return await useCase.execute(shopId);
});

final adminMissingItemsProvider = FutureProvider<Map<String, List<MissingItemEntity>>>((ref) async {
  final useCase = ref.watch(getGroupedMissingItemsUseCaseProvider);
  return await useCase.execute();
});

class MissingItemNotifier extends StateNotifier<AsyncValue<void>> {
  final SubmitMissingItemUseCase _submitUseCase;
  final DeleteMissingItemUseCase _deleteUseCase;
  final Ref _ref;

  MissingItemNotifier(this._submitUseCase, this._deleteUseCase, this._ref) 
      : super(const AsyncValue.data(null));

  Future<void> submitItem({
    required String itemName,
    required int quantity,
    required String shopId,
    String? notes,
    String? id,
  }) async {
    state = const AsyncValue.loading();
    
    try {
      await _submitUseCase.execute(
        itemName: itemName,
        quantity: quantity,
        shopId: shopId,
        notes: notes,
        id: id,
      );
      
      state = const AsyncValue.data(null);
      
      _ref.invalidate(shopMissingItemsProvider);
      _ref.invalidate(adminMissingItemsProvider);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> deleteItem(String id) async {
    state = const AsyncValue.loading();
    
    try {
      await _deleteUseCase.execute(id);
      
      state = const AsyncValue.data(null);
      
      _ref.invalidate(shopMissingItemsProvider);
      _ref.invalidate(adminMissingItemsProvider);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

final missingItemNotifierProvider = StateNotifierProvider<MissingItemNotifier, AsyncValue<void>>((ref) {
  return MissingItemNotifier(
    ref.watch(submitMissingItemUseCaseProvider),
    ref.watch(deleteMissingItemUseCaseProvider),
    ref,
  );
});