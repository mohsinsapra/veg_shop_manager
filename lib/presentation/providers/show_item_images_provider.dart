import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'management_providers.dart';

/// Whether swipe cards show the product photo as a full-card background.
/// This is a shared, admin-controlled setting stored in Firestore
/// (`settings/app.showItemImages`), off by default when the doc/field is
/// missing.
final showItemImagesProvider = StreamProvider<bool>((ref) {
  return ref.watch(settingsRepositoryProvider).watchShowItemImages();
});
