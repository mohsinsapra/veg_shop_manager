import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/storage/storage_service.dart';

/// Locales the app supports. Spanish is the default.
const supportedAppLocales = [Locale('es'), Locale('en')];
const defaultAppLocale = Locale('es');

class LocaleController extends StateNotifier<Locale> {
  LocaleController(this._storage, Locale initial) : super(initial);

  final StorageService _storage;

  void setLocale(Locale locale) {
    state = locale;
    _storage.setLocale(locale.languageCode);
  }
}

/// Overridden in main() with the persisted locale (or the Spanish default).
final localeProvider =
    StateNotifierProvider<LocaleController, Locale>((ref) {
  throw UnimplementedError('localeProvider must be overridden in main()');
});
