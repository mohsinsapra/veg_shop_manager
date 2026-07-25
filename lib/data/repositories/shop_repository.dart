import '../datasources/remote/firestore_refs.dart';
import '../../core/firebase/stream_retry.dart';
import '../../domain/entities/shop_entity.dart';

class ShopRepository {
  final FirestoreRefs _refs;
  ShopRepository(this._refs);

  Stream<List<ShopEntity>> watchAll() => retryingSnapshots(() =>
      _refs.shops.orderBy('sortOrder').snapshots().map((snap) =>
          snap.docs.map((d) => ShopEntity.fromMap(d.id, d.data())).toList()));

  Future<void> upsert(ShopEntity shop) =>
      _refs.shops.doc(shop.id).set(shop.toMap());

  Future<void> setActive(String id, bool active) =>
      _refs.shops.doc(id).update({'active': active});

  /// Persists a new listing order (id -> sortOrder) in one atomic batch. Used by
  /// drag-and-drop reordering; only changed items need to be passed.
  Future<void> setSortOrders(Map<String, int> idToSortOrder) async {
    if (idToSortOrder.isEmpty) return;
    final batch = _refs.db.batch();
    idToSortOrder.forEach((id, order) {
      batch.update(_refs.shops.doc(id), {'sortOrder': order});
    });
    await batch.commit();
  }
}
