import '../../core/constants/app_constants.dart';
import '../../core/constants/item_images.dart';
import '../../domain/entities/catalog_item_entity.dart';
import '../../domain/entities/shop_entity.dart';
import '../../domain/entities/member_entity.dart';
import '../repositories/catalog_repository.dart';
import '../repositories/shop_repository.dart';
import '../repositories/member_repository.dart';

class SeedService {
  final CatalogRepository catalog;
  final ShopRepository shops;
  final MemberRepository members;

  SeedService({required this.catalog, required this.shops, required this.members});

  Future<void> seedCatalogIfEmpty() async {
    if (await catalog.count() > 0) return;

    // Flatten (name, category) preserving category declaration order.
    final all = <MapEntry<String, String>>[];
    AppConstants.predefinedItems.forEach((category, items) {
      for (final name in items) {
        all.add(MapEntry(name, category));
      }
    });

    // Order by the paper sheet sequence; items not on the paper are appended
    // after, keeping their original relative order.
    final paperIndex = {
      for (var i = 0; i < AppConstants.paperOrder.length; i++)
        AppConstants.paperOrder[i]: i,
    };
    final origIndex = {for (var i = 0; i < all.length; i++) all[i].key: i};
    all.sort((a, b) {
      final ia = paperIndex[a.key] ??
          (AppConstants.paperOrder.length + origIndex[a.key]!);
      final ib = paperIndex[b.key] ??
          (AppConstants.paperOrder.length + origIndex[b.key]!);
      return ia.compareTo(ib);
    });

    var order = 0;
    for (final entry in all) {
      await catalog.upsert(CatalogItemEntity(
        id: 'seed_${order.toString().padLeft(4, '0')}',
        name: entry.key,
        category: entry.value,
        sortOrder: order,
        active: true,
        imageUrl: ItemImages.byName[entry.key] ?? '',
      ));
      order++;
    }
  }

  Future<void> seedShopsIfEmpty() async {
    final existing = await shops.watchAll().first;
    if (existing.isNotEmpty) return;
    var order = 0;
    for (final entry in AppConstants.predefinedShops.entries) {
      final name = entry.value;

      // Derive code from location word (after last ' - '), or fallback to key digits
      String code;
      if (name.contains(' - ')) {
        final locationPart = name.split(' - ').last.trim();
        if (locationPart.isNotEmpty && locationPart[0].toUpperCase().compareTo('A') >= 0 && locationPart[0].toUpperCase().compareTo('Z') <= 0) {
          code = locationPart[0].toUpperCase();
        } else {
          // Fallback: extract digits from entry.key
          final digits = RegExp(r'\d+').firstMatch(entry.key)?.group(0);
          code = digits ?? '?';
        }
      } else {
        // Fallback: extract digits from entry.key
        final digits = RegExp(r'\d+').firstMatch(entry.key)?.group(0);
        code = digits ?? '?';
      }

      await shops.upsert(ShopEntity(
        id: entry.key,
        name: name,
        code: code,
        sortOrder: order,
        active: true,
      ));
      order++;
    }
  }

  Future<void> seedAdmin(String email, String displayName) async {
    final id = email.toLowerCase();
    await members.upsert(MemberEntity(
      id: id,
      email: id,
      displayName: displayName,
      role: MemberRole.admin,
      shopIds: const [],
      active: true,
      uid: null,
    ));
  }
}
