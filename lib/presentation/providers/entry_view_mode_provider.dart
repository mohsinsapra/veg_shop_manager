import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/entry_item_controls.dart';

/// Remembers the entry-screen view mode (list / grid / swipe) across sessions
/// on this device, so the user's last choice is restored next time they add
/// items.
class EntryViewModeController extends StateNotifier<EntryViewMode> {
  EntryViewModeController() : super(EntryViewMode.swipe) {
    _load();
  }

  static const _key = 'entry_view_mode';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null) {
      state = EntryViewMode.values.firstWhere(
        (m) => m.name == saved,
        orElse: () => EntryViewMode.swipe,
      );
    }
  }

  Future<void> set(EntryViewMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}

final entryViewModeProvider =
    StateNotifierProvider<EntryViewModeController, EntryViewMode>((ref) {
  return EntryViewModeController();
});
