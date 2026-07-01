import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veg_shop_manager/data/datasources/remote/firestore_refs.dart';
import 'package:veg_shop_manager/data/repositories/cycle_repository.dart';
import 'package:veg_shop_manager/data/repositories/entry_repository.dart';
import 'package:veg_shop_manager/data/repositories/shop_repository.dart';
import 'package:veg_shop_manager/domain/entities/shop_entity.dart';
import 'package:veg_shop_manager/presentation/pages/admin/admin_dashboard_page.dart';
import 'package:veg_shop_manager/presentation/providers/firebase_providers.dart';

void main() {
  testWidgets('AdminDashboardPage pivots entries by item with total', (tester) async {
    final fake = FakeFirebaseFirestore();
    final refs = FirestoreRefs(fake);
    final now = DateTime.utc(2026, 7, 1);
    await ShopRepository(refs).upsert(const ShopEntity(
        id: 's1', name: 'Downtown', code: 'D', sortOrder: 0, active: true));
    final cycle = await CycleRepository(refs).ensureOpenCycle(now);
    await EntryRepository(refs).setQuantity(
        cycleId: cycle.id, shopId: 's1', itemId: 'i1', itemName: 'Apio',
        quantity: 5, createdBy: 'ana@x.com', now: now);

    await tester.pumpWidget(ProviderScope(
      overrides: [firebaseFirestoreProvider.overrideWithValue(fake)],
      child: const MaterialApp(home: Scaffold(body: AdminDashboardPage())),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Apio'), findsOneWidget);
    expect(find.text('5'), findsWidgets); // total badge
  });
}
