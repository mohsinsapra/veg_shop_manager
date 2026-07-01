import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:veg_shop_manager/l10n/app_localizations.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import '../core/constants/app_constants.dart';
import '../presentation/providers/locale_provider.dart';
import '../presentation/providers/theme_mode_provider.dart';

class VegShopApp extends ConsumerWidget {
  const VegShopApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Language and theme default to Spanish / light for everyone. Only the owner
    // can change these (via the gated Settings screen), which updates the
    // providers below; for all other users they stay at their defaults.
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: AppConstants.appName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerDelegate: AppRouter.routerDelegate,
      routeInformationParser: AppRouter.routeInformationParser,
      debugShowCheckedModeBanner: false,
    );
  }
}