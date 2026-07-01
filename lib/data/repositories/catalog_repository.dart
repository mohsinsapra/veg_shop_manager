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

  Future<int> count() async => (await _refs.catalogItems.count().get()).count ?? 0;
}
