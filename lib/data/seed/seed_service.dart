import '../../core/constants/app_constants.dart';
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
    var order = 0;
    for (final entry in AppConstants.predefinedItems.entries) {
      for (final name in entry.value) {
        await catalog.upsert(CatalogItemEntity(
          id: 'seed_${order.toString().padLeft(4, '0')}',
          name: name,
          category: entry.key,
          sortOrder: order,
          active: true,
        ));
        order++;
      }
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
