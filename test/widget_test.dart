// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:veg_shop_manager/app/app.dart';
import 'package:veg_shop_manager/data/models/missing_item.dart';
import 'package:veg_shop_manager/data/models/user_role.dart';
import 'package:veg_shop_manager/core/constants/app_constants.dart';

void main() {
  setUpAll(() async {
    await Hive.initFlutter();
    Hive.registerAdapter(MissingItemAdapter());
    Hive.registerAdapter(UserRoleAdapter());
  });

  testWidgets('App starts with login page', (WidgetTester tester) async {
    await Hive.openBox<MissingItem>(AppConstants.hiveBoxMissingItems);
    await Hive.openBox<String>(AppConstants.hiveBoxAuth);

    await tester.pumpWidget(const ProviderScope(child: VegShopApp()));

    expect(find.text('Frutas Deliciosas'), findsOneWidget);
    expect(find.text('Multi-Shop Vegetable Stock Manager'), findsOneWidget);
    
    await Hive.close();
  });
}
