import '../datasources/remote/firestore_refs.dart';
import '../../core/firebase/stream_retry.dart';
import '../../domain/entities/catalog_item_entity.dart';

class CatalogRepository {
  final FirestoreRefs _refs;
  CatalogRepository(this._refs);

  Stream<List<CatalogItemEntity>> watchAll() => retryingSnapshots(() =>
      _refs.catalogItems.orderBy('sortOrder').snapshots().map((snap) =>
          snap.docs.map((d) => CatalogItemEntity.fromMap(d.id, d.data())).toList()));

  Future<void> upsert(CatalogItemEntity item) =>
      _refs.catalogItems.doc(item.id).set(item.toMap());

  Future<void> setActive(String id, bool active) =>
      _refs.catalogItems.doc(id).update({'active': active});

  /// Persists a new listing order (id -> sortOrder) in one atomic batch. Used by
  /// drag-and-drop reordering; only changed items need to be passed.
  Future<void> setSortOrders(Map<String, int> idToSortOrder) async {
    if (idToSortOrder.isEmpty) return;
    final batch = _refs.db.batch();
    idToSortOrder.forEach((id, order) {
      batch.update(_refs.catalogItems.doc(id), {'sortOrder': order});
    });
    await batch.commit();
  }

  Future<int> count() async => (await _refs.catalogItems.count().get()).count ?? 0;
}
