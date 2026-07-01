import 'package:flutter_test/flutter_test.dart';
import 'package:veg_shop_manager/domain/entities/shop_entity.dart';
import 'package:veg_shop_manager/domain/entities/catalog_item_entity.dart';
import 'package:veg_shop_manager/domain/entities/member_entity.dart';
import 'package:veg_shop_manager/domain/entities/cycle_entity.dart';

void main() {
  test('ShopEntity round-trips through map', () {
    const shop = ShopEntity(id: 's1', name: 'Downtown', code: 'L', sortOrder: 0, active: true);
    final map = shop.toMap();
    expect(map['code'], 'L');
    expect(ShopEntity.fromMap('s1', map), shop);
  });

  test('CatalogItemEntity round-trips through map', () {
    const item = CatalogItemEntity(id: 'i1', name: 'Aguacate', category: 'Vegetables', sortOrder: 3, active: true);
    expect(CatalogItemEntity.fromMap('i1', item.toMap()), item);
  });

  test('MemberEntity round-trips and lowercases email', () {
    const m = MemberEntity(
      id: 'a@b.com', email: 'a@b.com', displayName: 'Ana',
      role: MemberRole.admin, shopIds: ['s1', 's2'], active: true, uid: null,
    );
    final map = m.toMap();
    expect(map['role'], 'admin');
    expect(map['shopIds'], ['s1', 's2']);
    expect(MemberEntity.fromMap('a@b.com', map), m);
  });

  test('CycleEntity round-trips status', () {
    final c = CycleEntity(
      id: 'c1', status: CycleStatus.open,
      openedAt: DateTime.utc(2026, 7, 1), completedAt: null,
    );
    final map = c.toMap();
    expect(map['status'], 'open');
    expect(CycleEntity.fromMap('c1', map), c);
  });
}
