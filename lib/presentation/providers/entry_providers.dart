import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/cycle_repository.dart';
import '../../data/repositories/entry_repository.dart';
import '../../domain/entities/cycle_entity.dart';
import '../../domain/entities/entry_entity.dart';
import 'firebase_providers.dart';

final cycleRepositoryProvider = Provider<CycleRepository>((ref) {
  return CycleRepository(ref.watch(firestoreRefsProvider));
});

final entryRepositoryProvider = Provider<EntryRepository>((ref) {
  return EntryRepository(ref.watch(firestoreRefsProvider));
});

final openCycleProvider = StreamProvider<CycleEntity?>((ref) {
  return ref.watch(cycleRepositoryProvider).watchOpenCycle();
});

/// All entries in the current open cycle (admin pivot dashboard).
final openCycleEntriesProvider = StreamProvider<List<EntryEntity>>((ref) {
  final cycle = ref.watch(openCycleProvider).valueOrNull;
  if (cycle == null) return Stream.value(const []);
  return ref.watch(entryRepositoryProvider).watchByCycle(cycle.id);
});

/// Entries for one shop in the current open cycle (member entry screen).
final shopEntriesProvider =
    StreamProvider.family<List<EntryEntity>, String>((ref, shopId) {
  final cycle = ref.watch(openCycleProvider).valueOrNull;
  if (cycle == null) return Stream.value(const []);
  return ref.watch(entryRepositoryProvider).watchByCycleAndShop(cycle.id, shopId);
});

final completedCyclesProvider = StreamProvider<List<CycleEntity>>((ref) {
  return ref.watch(cycleRepositoryProvider).watchCompleted();
});

/// Actions that need to coordinate cycle + entries (ensure an open cycle etc.).
class EntryActions {
  final CycleRepository _cycles;
  final EntryRepository _entries;
  EntryActions(this._cycles, this._entries);

  Future<void> submitQuantity({
    required String shopId,
    required String itemId,
    required String itemName,
    required int quantity,
    required String createdBy,
    String? notes,
  }) async {
    final now = DateTime.now().toUtc();
    final cycle = await _cycles.ensureOpenCycle(now);
    await _entries.setQuantity(
      cycleId: cycle.id,
      shopId: shopId,
      itemId: itemId,
      itemName: itemName,
      quantity: quantity,
      createdBy: createdBy,
      now: now,
      notes: notes,
    );
  }

  Future<void> setBought(String entryId, bool bought) =>
      _entries.setBought(entryId, bought);

  Future<void> setBoughtBatch(Iterable<String> entryIds, bool bought) =>
      _entries.setBoughtBatch(entryIds, bought);

  Future<void> completeCurrentCycle() async {
    final cycle = await _cycles.getOpenCycle();
    if (cycle != null) {
      await _cycles.completeCycle(cycle.id, DateTime.now().toUtc());
    }
  }
}

final entryActionsProvider = Provider<EntryActions>((ref) {
  return EntryActions(
    ref.watch(cycleRepositoryProvider),
    ref.watch(entryRepositoryProvider),
  );
});
