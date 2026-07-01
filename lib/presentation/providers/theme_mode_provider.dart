import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/storage/storage_service.dart';

/// The app defaults to the light (brand) theme. Only the owner can change this
/// via the Settings screen; everyone else stays on [defaultThemeMode] because
/// no other UI mutates the provider.
const defaultThemeMode = ThemeMode.light;

ThemeMode themeModeFromName(String? name) {
  switch (name) {
    case 'dark':
      return ThemeMode.dark;
    case 'system':
      return ThemeMode.system;
    case 'light':
      return ThemeMode.light;
    default:
      return defaultThemeMode;
  }
}

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController(this._storage, ThemeMode initial) : super(initial);

  final StorageService _storage;

  void setThemeMode(ThemeMode mode) {
    state = mode;
    _storage.setThemeMode(mode.name);
  }
}

/// Overridden in main() with the persisted theme mode (or the light default).
final themeModeProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>((ref) {
  throw UnimplementedError('themeModeProvider must be overridden in main()');
});
