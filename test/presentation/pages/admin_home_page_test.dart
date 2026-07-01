import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veg_shop_manager/presentation/pages/admin/admin_home_page.dart';
import 'package:veg_shop_manager/presentation/providers/firebase_providers.dart';

void main() {
  testWidgets('AdminHomePage shows navigation destinations', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        firebaseAuthProvider.overrideWithValue(MockFirebaseAuth()),
        firebaseFirestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
      ],
      child: const MaterialApp(home: AdminHomePage()),
    ));
    await tester.pump();
    expect(find.text('Shops'), findsWidgets);
    expect(find.text('Catalog'), findsWidgets);
    expect(find.text('Members'), findsWidgets);
  });
}
