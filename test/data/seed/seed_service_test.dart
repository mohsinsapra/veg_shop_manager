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

  test('seedShopsIfEmpty creates the predefined shops with codes', () async {
    await seed.seedShopsIfEmpty();
    final list = await shops.watchAll().first;
    expect(list.length, AppConstants.predefinedShops.length);
    expect(list.every((s) => s.code.isNotEmpty), true);
  });

  test('seedAdmin creates an active admin member', () async {
    await seed.seedAdmin('owner@x.com', 'Owner');
    final m = await members.findByEmail('owner@x.com');
    expect(m?.isAdmin, true);
    expect(m?.active, true);
  });
}
