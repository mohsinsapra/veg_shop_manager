import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veg_shop_manager/data/repositories/shop_repository.dart';
import 'package:veg_shop_manager/data/datasources/remote/firestore_refs.dart';
import 'package:veg_shop_manager/domain/entities/shop_entity.dart';
import 'package:veg_shop_manager/presentation/providers/firebase_providers.dart';
import 'package:veg_shop_manager/presentation/providers/management_providers.dart';

void main() {
  test('shopsProvider streams shops from Firestore', () async {
    final fake = FakeFirebaseFirestore();
    await ShopRepository(FirestoreRefs(fake)).upsert(const ShopEntity(
        id: 's1', name: 'Downtown', code: 'D', sortOrder: 0, active: true));
    final container = ProviderContainer(overrides: [
      firebaseFirestoreProvider.overrideWithValue(fake),
    ]);
    addTearDown(container.dispose);

    final shops = await container.read(shopsProvider.future);
    expect(shops.single.code, 'D');
  });
}
