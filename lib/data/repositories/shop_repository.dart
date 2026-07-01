import '../datasources/remote/firestore_refs.dart';
import '../../domain/entities/shop_entity.dart';

class ShopRepository {
  final FirestoreRefs _refs;
  ShopRepository(this._refs);

  Stream<List<ShopEntity>> watchAll() =>
      _refs.shops.orderBy('sortOrder').snapshots().map((snap) =>
          snap.docs.map((d) => ShopEntity.fromMap(d.id, d.data())).toList());

  Future<void> upsert(ShopEntity shop) =>
      _refs.shops.doc(shop.id).set(shop.toMap());

  Future<void> setActive(String id, bool active) =>
      _refs.shops.doc(id).update({'active': active});
}
