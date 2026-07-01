import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veg_shop_manager/data/datasources/remote/firestore_refs.dart';
import 'package:veg_shop_manager/data/repositories/shop_repository.dart';
import 'package:veg_shop_manager/data/repositories/catalog_repository.dart';
import 'package:veg_shop_manager/data/repositories/member_repository.dart';
import 'package:veg_shop_manager/domain/entities/shop_entity.dart';
import 'package:veg_shop_manager/domain/entities/catalog_item_entity.dart';
import 'package:veg_shop_manager/domain/entities/member_entity.dart';

void main() {
  late FirestoreRefs refs;
  setUp(() => refs = FirestoreRefs(FakeFirebaseFirestore()));

  test('ShopRepository upserts and streams sorted by sortOrder', () async {
    final repo = ShopRepository(refs);
    await repo.upsert(const ShopEntity(id: 's2', name: 'Mall', code: 'S', sortOrder: 1, active: true));
    await repo.upsert(const ShopEntity(id: 's1', name: 'Downtown', code: 'L', sortOrder: 0, active: true));
    final shops = await repo.watchAll().first;
    expect(shops.map((s) => s.id), ['s1', 's2']);
  });

  test('CatalogRepository counts items', () async {
    final repo = CatalogRepository(refs);
    await repo.upsert(const CatalogItemEntity(id: 'i1', name: 'Apio', category: 'Vegetables', sortOrder: 0, active: true));
    expect(await repo.count(), 1);
  });

  test('MemberRepository finds by email case-insensitively', () async {
    final repo = MemberRepository(refs);
    await repo.upsert(const MemberEntity(
      id: 'ana@x.com', email: 'ana@x.com', displayName: 'Ana',
      role: MemberRole.member, shopIds: ['s1'], active: true, uid: null));
    final found = await repo.findByEmail('ANA@x.com');
    expect(found?.displayName, 'Ana');
  });

  test('MemberRepository linkUid updates uid only', () async {
    final repo = MemberRepository(refs);
    await repo.upsert(const MemberEntity(
      id: 'ana@x.com', email: 'ana@x.com', displayName: 'Ana',
      role: MemberRole.member, shopIds: ['s1'], active: true, uid: null));
    await repo.linkUid('ana@x.com', 'uid-123');
    expect((await repo.findByEmail('ana@x.com'))?.uid, 'uid-123');
  });
}
