import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veg_shop_manager/data/datasources/remote/firestore_refs.dart';
import 'package:veg_shop_manager/data/repositories/catalog_repository.dart';
import 'package:veg_shop_manager/data/repositories/member_repository.dart';
import 'package:veg_shop_manager/domain/entities/catalog_item_entity.dart';
import 'package:veg_shop_manager/domain/entities/member_entity.dart';

void main() {
  late FirestoreRefs refs;
  setUp(() => refs = FirestoreRefs(FakeFirebaseFirestore()));

  test('MemberRepository.upsert lowercases the doc id so findByEmail matches', () async {
    final repo = MemberRepository(refs);
    await repo.upsert(const MemberEntity(
        id: 'Ana@X.com', email: 'Ana@X.com', displayName: 'Ana',
        role: MemberRole.member, shopIds: ['s1'], active: true, uid: null));
    final found = await repo.findByEmail('ana@x.com');
    expect(found?.displayName, 'Ana');
    expect(found?.email, 'ana@x.com');
  });

  test('MemberRepository.setActive toggles active only', () async {
    final repo = MemberRepository(refs);
    await repo.upsert(const MemberEntity(
        id: 'ana@x.com', email: 'ana@x.com', displayName: 'Ana',
        role: MemberRole.member, shopIds: ['s1'], active: true, uid: null));
    await repo.setActive('ana@x.com', false);
    expect((await repo.findByEmail('ana@x.com'))?.active, false);
  });

  test('CatalogRepository.setActive toggles active', () async {
    final repo = CatalogRepository(refs);
    await repo.upsert(const CatalogItemEntity(
        id: 'i1', name: 'Apio', category: 'Vegetables', sortOrder: 0, active: true));
    await repo.setActive('i1', false);
    final items = await repo.watchAll().first;
    expect(items.single.active, false);
  });
}
