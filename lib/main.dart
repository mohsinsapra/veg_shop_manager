import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'core/firebase/firebase_init.dart';
import 'core/storage/storage_service.dart';
import 'presentation/pdf/print_helpers.dart';
import 'presentation/providers/locale_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initFirebase();

  final storageService = StorageServiceFactory.instance;
  await storageService.init();

  final savedCode = await storageService.getLocale();
  final initialLocale = savedCode == null
      ? defaultAppLocale
      : (savedCode == 'en' ? const Locale('en') : const Locale('es'));

  runApp(
    ProviderScope(
      overrides: [
        localeProvider.overrideWith(
          (ref) => LocaleController(storageService, initialLocale),
        ),
      ],
      child: const VegShopApp(),
    ),
  );

  // Warm the PDF fonts so the first print (esp. mobile share) isn't blocked.
  preloadPdfFonts();
}
