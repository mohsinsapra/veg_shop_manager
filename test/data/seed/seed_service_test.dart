import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veg_shop_manager/core/constants/app_constants.dart';
import 'package:veg_shop_manager/data/datasources/remote/firestore_refs.dart';
import 'package:veg_shop_manager/data/repositories/catalog_repository.dart';
import 'package:veg_shop_manager/data/repositories/shop_repository.dart';
import 'package:veg_shop_manager/data/repositories/member_repository.dart';
import 'package:veg_shop_manager/data/seed/seed_service.dart';

void main() {
  late SeedService seed;
  late CatalogRepository catalog;
  late ShopRepository shops;
  late MemberRepository members;

  setUp(() {
    final refs = FirestoreRefs(FakeFirebaseFirestore());
    catalog = CatalogRepository(refs);
    shops = ShopRepository(refs);
    members = MemberRepository(refs);
    seed = SeedService(catalog: catalog, shops: shops, members: members);
  });

  test('seedCatalogIfEmpty loads all predefined items once', () async {
    await seed.seedCatalogIfEmpty();
    final expected = AppConstants.allPredefinedItems.length;
    expect(await catalog.count(), expected);
    // idempotent
    await seed.seedCatalogIfEmpty();
    expect(await catalog.count(), expected);
  });

  test('seedShopsIfEmpty creates the predefined shops with distinct codes', () async {
    await seed.seedShopsIfEmpty();
    final list = await shops.watchAll().first;
    expect(list.length, AppConstants.predefinedShops.length);

    // All codes must be non-empty
    expect(list.every((s) => s.code.isNotEmpty), true);

    // All codes must be distinct
    final codes = list.map((s) => s.code).toSet();
    expect(codes.length, list.length, reason: 'All shop codes must be unique');

    // Expected codes based on location words after the last ' - '
    final shopsByKey = {for (final s in list) s.id: s};
    expect(shopsByKey['shop1']?.code, 'D', reason: 'shop1 (Downtown) should have code D');
    expect(shopsByKey['shop2']?.code, 'M', reason: 'shop2 (Mall) should have code M');
    expect(shopsByKey['shop3']?.code, 'S', reason: 'shop3 (Suburb) should have code S');
  });

  test('seedAdmin creates an active admin member', () async {
    await seed.seedAdmin('owner@x.com', 'Owner');
    final m = await members.findByEmail('owner@x.com');
    expect(m?.isAdmin, true);
    expect(m?.active, true);
  });
}
