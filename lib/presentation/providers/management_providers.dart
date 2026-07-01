import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/shop_repository.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../domain/entities/shop_entity.dart';
import '../../domain/entities/catalog_item_entity.dart';
import '../../domain/entities/member_entity.dart';
import 'firebase_providers.dart';
import 'firebase_auth_provider.dart';

final shopRepositoryProvider = Provider<ShopRepository>((ref) {
  return ShopRepository(ref.watch(firestoreRefsProvider));
});

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepository(ref.watch(firestoreRefsProvider));
});

final shopsProvider = StreamProvider<List<ShopEntity>>((ref) {
  return ref.watch(shopRepositoryProvider).watchAll();
});

final catalogProvider = StreamProvider<List<CatalogItemEntity>>((ref) {
  return ref.watch(catalogRepositoryProvider).watchAll();
});

final membersProvider = StreamProvider<List<MemberEntity>>((ref) {
  return ref.watch(memberRepositoryProvider).watchAll();
});
