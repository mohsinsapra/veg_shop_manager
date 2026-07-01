import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import '../../presentation/pages/login/login_page.dart';
import '../../presentation/pages/shop/shop_home_page.dart';
import '../../presentation/pages/shop/add_item_page.dart';
import '../../presentation/pages/shop/quick_add_item_page.dart';
import '../../presentation/pages/shop/step_by_step_add_page.dart';
import '../../presentation/pages/admin/admin_page.dart';
import '../../presentation/pages/admin/debug_admin_page.dart';
import '../../presentation/pages/admin/shopping_history_page.dart';

class AppRouter {
  static final routerDelegate = BeamerDelegate(
    initialPath: '/',
    locationBuilder: RoutesLocationBuilder(
      routes: {
        '/': (context, state, data) => const BeamPage(
          key: ValueKey('login'),
          child: LoginPage(),
        ),
        '/shop': (context, state, data) => const BeamPage(
          key: ValueKey('shop'),
          child: ShopHomePage(),
        ),
        '/shop/add': (context, state, data) => const BeamPage(
          key: ValueKey('shop-add'),
          child: AddItemPage(),
        ),
        '/shop/quick-add': (context, state, data) => const BeamPage(
          key: ValueKey('shop-quick-add'),
          child: QuickAddItemPage(),
        ),
        '/shop/step-add': (context, state, data) => const BeamPage(
          key: ValueKey('shop-step-add'),
          child: StepByStepAddPage(),
        ),
        '/admin': (context, state, data) => const BeamPage(
          key: ValueKey('admin'),
          child: AdminPage(),
        ),
        '/admin/debug': (context, state, data) => const BeamPage(
          key: ValueKey('debug-admin'),
          child: DebugAdminPage(),
        ),
        '/admin/history': (context, state, data) => const BeamPage(
          key: ValueKey('shopping-history'),
          child: ShoppingHistoryPage(),
        ),
      },
    ),
  );

  static final routeInformationParser = BeamerParser();
}