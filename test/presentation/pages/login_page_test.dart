import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veg_shop_manager/presentation/pages/auth/login_page.dart';

void main() {
  testWidgets('LoginPage shows a Sign in with Google button', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: LoginPage()),
    ));
    expect(find.text('Sign in with Google'), findsOneWidget);
  });
}
