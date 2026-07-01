import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veg_shop_manager/data/datasources/remote/firestore_refs.dart';
import 'package:veg_shop_manager/data/repositories/catalog_repository.dart';
import 'package:veg_shop_manager/domain/entities/catalog_item_entity.dart';
import 'package:veg_shop_manager/presentation/providers/firebase_providers.dart';
import 'package:veg_shop_manager/presentation/pages/admin/catalog_management_page.dart';

void main() {
  testWidgets('CatalogManagementPage lists items by category', (tester) async {
    final fake = FakeFirebaseFirestore();
    await CatalogRepository(FirestoreRefs(fake)).upsert(const CatalogItemEntity(
        id: 'i1', name: 'Aguacate', category: 'Vegetables', sortOrder: 0, active: true));
    await tester.pumpWidget(ProviderScope(
      overrides: [firebaseFirestoreProvider.overrideWithValue(fake)],
      child: const MaterialApp(home: Scaffold(body: CatalogManagementPage())),
    ));
    await tester.pump();
    expect(find.text('Aguacate'), findsOneWidget);
    expect(find.text('Vegetables'), findsWidgets);
  });
}
