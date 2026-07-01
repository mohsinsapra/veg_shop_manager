import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veg_shop_manager/data/datasources/remote/firestore_refs.dart';
import 'package:veg_shop_manager/data/repositories/catalog_repository.dart';
import 'package:veg_shop_manager/data/repositories/member_repository.dart';
import 'package:veg_shop_manager/data/repositories/shop_repository.dart';
import 'package:veg_shop_manager/domain/entities/catalog_item_entity.dart';
import 'package:veg_shop_manager/domain/entities/member_entity.dart';
import 'package:veg_shop_manager/domain/entities/shop_entity.dart';
import 'package:veg_shop_manager/l10n/app_localizations.dart';
import 'package:veg_shop_manager/presentation/pages/shop/member_home_page.dart';
import 'package:veg_shop_manager/presentation/providers/firebase_providers.dart';

void main() {
  testWidgets('MemberHomePage shows the member\'s shop and catalog items',
      (tester) async {
    final fake = FakeFirebaseFirestore();
    final refs = FirestoreRefs(fake);
    await MemberRepository(refs).upsert(const MemberEntity(
        id: 'ana@x.com', email: 'ana@x.com', displayName: 'Ana',
        role: MemberRole.member, shopIds: ['s1'], active: true, uid: null));
    await ShopRepository(refs).upsert(const ShopEntity(
        id: 's1', name: 'Downtown', code: 'D', sortOrder: 0, active: true));
    await CatalogRepository(refs).upsert(const CatalogItemEntity(
        id: 'i1', name: 'Apio', category: 'Vegetables', sortOrder: 0, active: true));

    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(email: 'ana@x.com', uid: 'u1'),
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        firebaseAuthProvider.overrideWithValue(auth),
        firebaseFirestoreProvider.overrideWithValue(fake),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const MemberHomePage(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Apio'), findsOneWidget);
    expect(find.textContaining('Downtown'), findsWidgets);
  });
}
