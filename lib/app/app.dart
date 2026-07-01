import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:veg_shop_manager/l10n/app_localizations.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import '../core/constants/app_constants.dart';
import '../presentation/providers/locale_provider.dart';

class VegShopApp extends ConsumerWidget {
  const VegShopApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Language switching is disabled: always render in the default locale.
    return MaterialApp.router(
      title: AppConstants.appName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      // Always use the light (brand) theme; ignore the device's dark mode so the
      // cream/green look stays consistent everywhere. Flip to ThemeMode.system
      // to re-enable dark mode.
      themeMode: ThemeMode.light,
      locale: defaultAppLocale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerDelegate: AppRouter.routerDelegate,
      routeInformationParser: AppRouter.routeInformationParser,
      debugShowCheckedModeBanner: false,
    );
  }
}