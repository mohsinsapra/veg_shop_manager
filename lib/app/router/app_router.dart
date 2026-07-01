import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import '../../presentation/pages/auth/auth_gate.dart';
import '../../presentation/pages/settings/settings_page.dart';

class AppRouter {
  static final routerDelegate = BeamerDelegate(
    initialPath: '/',
    // Keep the browser tab title from index.html ("GreenChain") instead of
    // letting Beamer replace it with the route path (e.g. "/").
    setBrowserTabTitle: false,
    locationBuilder: RoutesLocationBuilder(
      routes: {
        // The signed-in shell (admin dashboard / member entry) is rendered by
        // AuthGate based on role; the legacy Hive shop/admin pages are not part
        // of the cloud flow and are intentionally not routed.
        '/': (context, state, data) => const BeamPage(
          key: ValueKey('auth-gate'),
          child: AuthGate(),
        ),
        '/settings': (context, state, data) => const BeamPage(
          key: ValueKey('settings'),
          child: SettingsPage(),
        ),
      },
    ),
  );

  static final routeInformationParser = BeamerParser();
}
