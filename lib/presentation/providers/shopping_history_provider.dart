import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/local/shopping_history_local_ds.dart';
import '../../data/repositories/shopping_history_repository.dart';
import '../../domain/entities/shopping_history_entity.dart';
import '../../domain/usecases/shopping_history_usecases.dart';
import 'auth_provider.dart';
import 'missing_item_provider.dart';

final shoppingHistoryLocalDataSourceProvider = Provider<ShoppingHistoryLocalDataSource>((ref) {
  return ShoppingHistoryLocalDataSource(ref.watch(storageServiceProvider));
});

final shoppingHistoryRepositoryProvider = Provider<ShoppingHistoryRepository>((ref) {
  return ShoppingHistoryRepository(ref.watch(shoppingHistoryLocalDataSourceProvider));
});

final completeShoppingListUseCaseProvider = Provider<CompleteShoppingListUseCase>((ref) {
  return CompleteShoppingListUseCase(
    ref.watch(shoppingHistoryRepositoryProvider),
    ref.watch(missingItemRepositoryProvider),
  );
});

final getShoppingHistoryUseCaseProvider = Provider<GetShoppingHistoryUseCase>((ref) {
  return GetShoppingHistoryUseCase(ref.watch(shoppingHistoryRepositoryProvider));
});

final deleteShoppingHistoryUseCaseProvider = Provider<DeleteShoppingHistoryUseCase>((ref) {
  return DeleteShoppingHistoryUseCase(ref.watch(shoppingHistoryRepositoryProvider));
});

final shoppingHistoryProvider = FutureProvider<List<ShoppingHistoryEntity>>((ref) async {
  final useCase = ref.watch(getShoppingHistoryUseCaseProvider);
  return await useCase.execute();
});

class ShoppingHistoryNotifier extends StateNotifier<AsyncValue<void>> {
  final CompleteShoppingListUseCase _completeUseCase;
  final DeleteShoppingHistoryUseCase _deleteUseCase;
  final Ref _ref;

  ShoppingHistoryNotifier(this._completeUseCase, this._deleteUseCase, this._ref) 
      : super(const AsyncValue.data(null));

  Future<void> completeShoppingList() async {
    state = const AsyncValue.loading();
    
    try {
      await _completeUseCase.execute();
      
      state = const AsyncValue.data(null);
      
      // Refresh all related providers
      _ref.invalidate(adminMissingItemsProvider);
      _ref.invalidate(shopMissingItemsProvider);
      _ref.invalidate(shoppingHistoryProvider);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> deleteHistory(String id) async {
    state = const AsyncValue.loading();
    
    try {
      await _deleteUseCase.execute(id);
      
      state = const AsyncValue.data(null);
      
      _ref.invalidate(shoppingHistoryProvider);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

final shoppingHistoryNotifierProvider = StateNotifierProvider<ShoppingHistoryNotifier, AsyncValue<void>>((ref) {
  return ShoppingHistoryNotifier(
    ref.watch(completeShoppingListUseCaseProvider),
    ref.watch(deleteShoppingHistoryUseCaseProvider),
    ref,
  );
});