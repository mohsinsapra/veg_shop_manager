import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veg_shop_manager/data/datasources/remote/firestore_refs.dart';
import 'package:veg_shop_manager/data/repositories/shop_repository.dart';
import 'package:veg_shop_manager/domain/entities/shop_entity.dart';
import 'package:veg_shop_manager/presentation/providers/firebase_providers.dart';
import 'package:veg_shop_manager/presentation/pages/admin/shops_management_page.dart';

void main() {
  testWidgets('ShopsManagementPage lists shops', (tester) async {
    final fake = FakeFirebaseFirestore();
    await ShopRepository(FirestoreRefs(fake)).upsert(const ShopEntity(
        id: 's1', name: 'Downtown', code: 'D', sortOrder: 0, active: true));
    await tester.pumpWidget(ProviderScope(
      overrides: [firebaseFirestoreProvider.overrideWithValue(fake)],
      child: const MaterialApp(home: Scaffold(body: ShopsManagementPage())),
    ));
    await tester.pump();
    expect(find.text('Downtown'), findsOneWidget);
    expect(find.text('D'), findsWidgets);
  });
}
