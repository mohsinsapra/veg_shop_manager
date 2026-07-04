import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether swipe cards show the product photo as a full-card background.
/// Off by default (text only); toggled from the owner Settings page and
/// remembered per device.
class ShowItemImagesController extends StateNotifier<bool> {
  ShowItemImagesController() : super(false) {
    _load();
  }

  static const _key = 'show_item_images';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false;
  }

  Future<void> set(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}

final showItemImagesProvider =
    StateNotifierProvider<ShowItemImagesController, bool>((ref) {
  return ShowItemImagesController();
});
