import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veg_shop_manager/data/datasources/remote/firestore_refs.dart';
import 'package:veg_shop_manager/data/repositories/catalog_repository.dart';
import 'package:veg_shop_manager/domain/entities/catalog_item_entity.dart';
import 'package:veg_shop_manager/l10n/app_localizations.dart';
import 'package:veg_shop_manager/presentation/providers/firebase_providers.dart';
import 'package:veg_shop_manager/presentation/pages/admin/catalog_management_page.dart';

void main() {
  Future<FakeFirebaseFirestore> pumpPage(
    WidgetTester tester,
    CatalogItemEntity item,
  ) async {
    final fake = FakeFirebaseFirestore();
    await CatalogRepository(FirestoreRefs(fake)).upsert(item);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [firebaseFirestoreProvider.overrideWithValue(fake)],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: CatalogManagementPage()),
        ),
      ),
    );
    await tester.pump();
    return fake;
  }

  testWidgets('editing image URL and saving persists it', (tester) async {
    final fake = await pumpPage(
      tester,
      const CatalogItemEntity(
        id: 'i1',
        name: 'Aguacate',
        category: 'Vegetables',
        sortOrder: 0,
        active: true,
      ),
    );

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pump();

    final urlField = find.widgetWithText(TextFormField, 'Image URL (optional)');
    expect(urlField, findsOneWidget);
    await tester.enterText(urlField, 'https://example.com/avocado.jpg');
    await tester.pump();

    await tester.tap(find.text('Save'));
    await tester.pump();

    final doc = await fake.collection('catalogItems').doc('i1').get();
    expect(doc.data()?['imageUrl'], 'https://example.com/avocado.jpg');
  });

  testWidgets('clearing image URL and saving stores empty imageUrl', (
    tester,
  ) async {
    final fake = await pumpPage(
      tester,
      const CatalogItemEntity(
        id: 'i2',
        name: 'Limón',
        category: 'Fruits',
        sortOrder: 0,
        active: true,
        imageUrl: 'https://example.com/lemon.jpg',
      ),
    );

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pump();

    final urlField = find.widgetWithText(TextFormField, 'Image URL (optional)');
    expect(urlField, findsOneWidget);
    await tester.enterText(urlField, '');
    await tester.pump();

    await tester.tap(find.text('Save'));
    await tester.pump();

    final doc = await fake.collection('catalogItems').doc('i2').get();
    expect(doc.data()?['imageUrl'], '');
  });
}
