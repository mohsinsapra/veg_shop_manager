import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import '../../presentation/pages/login/login_page.dart';
import '../../presentation/pages/shop/shop_home_page.dart';
import '../../presentation/pages/shop/add_item_page.dart';
import '../../presentation/pages/admin/admin_page.dart';

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
        '/admin': (context, state, data) => const BeamPage(
          key: ValueKey('admin'),
          child: AdminPage(),
        ),
      },
    ),
  );

  static final routeInformationParser = BeamerParser();
}