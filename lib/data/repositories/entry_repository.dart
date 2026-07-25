import 'package:cloud_firestore/cloud_firestore.dart';
import '../datasources/remote/firestore_refs.dart';
import '../../core/firebase/stream_retry.dart';
import '../../domain/entities/entry_entity.dart';

class EntryRepository {
  final FirestoreRefs _refs;
  EntryRepository(this._refs);

  Stream<List<EntryEntity>> watchByCycle(String cycleId) =>
      retryingSnapshots(() => _refs.entries
          .where('cycleId', isEqualTo: cycleId)
          .snapshots()
          .map((snap) =>
              snap.docs.map((d) => EntryEntity.fromMap(d.id, d.data())).toList()));

  Stream<List<EntryEntity>> watchByCycleAndShop(String cycleId, String shopId) =>
      retryingSnapshots(() => _refs.entries
          .where('cycleId', isEqualTo: cycleId)
          .where('shopId', isEqualTo: shopId)
          .snapshots()
          .map((snap) =>
              snap.docs.map((d) => EntryEntity.fromMap(d.id, d.data())).toList()));

  Future<List<EntryEntity>> getByCycle(String cycleId) async {
    final snap = await _refs.entries.where('cycleId', isEqualTo: cycleId).get();
    return snap.docs.map((d) => EntryEntity.fromMap(d.id, d.data())).toList();
  }

  /// Sets a shop's needed quantity for an item in a cycle. A quantity <= 0
  /// removes the entry (the shop no longer needs the item).
  Future<void> setQuantity({
    required String cycleId,
    required String shopId,
    required String itemId,
    required String itemName,
    required double quantity,
    required String createdBy,
    required DateTime now,
    String? notes,
  }) =>
      setQuantityForShops(
        cycleId: cycleId,
        shopIds: [shopId],
        itemId: itemId,
        itemName: itemName,
        quantity: quantity,
        createdBy: createdBy,
        now: now,
        notes: notes,
      );

  /// Sets the same quantity for one item across [shopIds] in a single batch —
  /// one network roundtrip regardless of shop count. Uses merge writes (no
  /// read-before-write): an existing entry keeps its `bought` flag and
  /// `createdAt`; new entries get the defaults from [EntryEntity.fromMap].
  Future<void> setQuantityForShops({
    required String cycleId,
    required List<String> shopIds,
    required String itemId,
    required String itemName,
    required double quantity,
    required String createdBy,
    required DateTime now,
    String? notes,
  }) async {
    final batch = _refs.db.batch();
    for (final shopId in shopIds) {
      final id = EntryEntity.buildId(cycleId, shopId, itemId);
      final doc = _refs.entries.doc(id);
      if (quantity <= 0) {
        batch.delete(doc);
        continue;
      }
      final map = EntryEntity(
        id: id,
        cycleId: cycleId,
        itemId: itemId,
        itemName: itemName,
        shopId: shopId,
        quantity: quantity,
        notes: notes,
        bought: false,
        createdBy: createdBy,
        createdAt: now,
      ).toMap()
        ..remove('bought')
        ..remove('createdAt');
      batch.set(doc, map, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> setBought(String entryId, bool bought) =>
      _refs.entries.doc(entryId).update({'bought': bought});

  /// Marks many entries bought/unbought in one atomic batch (e.g. a whole item
  /// across shops, or the entire list at once).
  Future<void> setBoughtBatch(Iterable<String> entryIds, bool bought) async {
    final batch = _refs.db.batch();
    for (final id in entryIds) {
      batch.update(_refs.entries.doc(id), {'bought': bought});
    }
    await batch.commit();
  }

  Future<void> delete(String entryId) => _refs.entries.doc(entryId).delete();
}
