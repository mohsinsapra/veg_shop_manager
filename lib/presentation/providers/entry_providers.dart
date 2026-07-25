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

/// Live entries of one cycle, so expanded history cards reflect changes
/// immediately instead of showing a one-shot snapshot.
final cycleEntriesProvider =
    StreamProvider.family<List<EntryEntity>, String>((ref, cycleId) {
  return ref.watch(entryRepositoryProvider).watchByCycle(cycleId);
});

/// Actions that need to coordinate cycle + entries (ensure an open cycle etc.).
class EntryActions {
  final CycleRepository _cycles;
  final EntryRepository _entries;
  final CycleEntity? Function()? _cachedOpenCycle;
  EntryActions(this._cycles, this._entries,
      {CycleEntity? Function()? cachedOpenCycle})
      : _cachedOpenCycle = cachedOpenCycle;

  /// Uses the open cycle already held by the live stream when available,
  /// avoiding a server query on every quantity tap.
  Future<CycleEntity> _ensureCycle(DateTime now) async {
    final cached = _cachedOpenCycle?.call();
    if (cached != null) return cached;
    return _cycles.ensureOpenCycle(now);
  }

  Future<void> submitQuantity({
    required String shopId,
    required String itemId,
    required String itemName,
    required double quantity,
    required String createdBy,
    String? notes,
  }) =>
      submitQuantityToShops(
        shopIds: [shopId],
        itemId: itemId,
        itemName: itemName,
        quantity: quantity,
        createdBy: createdBy,
        notes: notes,
      );

  /// Same quantity for one item across many shops in one batched write.
  Future<void> submitQuantityToShops({
    required List<String> shopIds,
    required String itemId,
    required String itemName,
    required double quantity,
    required String createdBy,
    String? notes,
  }) async {
    final now = DateTime.now().toUtc();
    final cycle = await _ensureCycle(now);
    await _entries.setQuantityForShops(
      cycleId: cycle.id,
      shopIds: shopIds,
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
    cachedOpenCycle: () => ref.read(openCycleProvider).valueOrNull,
  );
});
