import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veg_shop_manager/presentation/pages/auth/login_page.dart';
import 'package:veg_shop_manager/presentation/providers/firebase_providers.dart';

void main() {
  testWidgets('LoginPage shows a Sign in with Google button', (tester) async {
    // LoginPage watches authControllerProvider, which builds the auth stack.
    // Override the Firebase instances with fakes so no real Firebase is needed.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(MockFirebaseAuth()),
          firebaseFirestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
        ],
        child: const MaterialApp(home: LoginPage()),
      ),
    );
    expect(find.text('Sign in with Google'), findsOneWidget);
  });
}
