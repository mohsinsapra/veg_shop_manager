import 'package:flutter_test/flutter_test.dart';
import 'package:veg_shop_manager/domain/entities/shop_entity.dart';
import 'package:veg_shop_manager/domain/entities/catalog_item_entity.dart';
import 'package:veg_shop_manager/domain/entities/entry_entity.dart';
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

  test('CatalogItemEntity.fromMap defaults unit/packSizes when absent (old docs)', () {
    final map = {'name': 'Aguacate', 'category': 'Vegetables', 'sortOrder': 3, 'active': true};
    final item = CatalogItemEntity.fromMap('i1', map);
    expect(item.unit, '');
    expect(item.packSizes, isEmpty);
  });

  test('CatalogItemEntity round-trips unit and packSizes', () {
    const item = CatalogItemEntity(
      id: 'i1',
      name: 'Zanahoria',
      category: 'Vegetables',
      sortOrder: 3,
      active: true,
      unit: 'kg',
      packSizes: [5, 10],
    );
    final map = item.toMap();
    expect(map['unit'], 'kg');
    expect(map['packSizes'], [5.0, 10.0]);
    expect(CatalogItemEntity.fromMap('i1', map), item);
  });

  test('EntryEntity round-trips packSize (null and set)', () {
    final plain = EntryEntity(
      id: EntryEntity.buildId('c1', 's1', 'i1'),
      cycleId: 'c1',
      itemId: 'i1',
      itemName: 'Zanahoria',
      shopId: 's1',
      quantity: 3,
      notes: null,
      bought: false,
      createdBy: 'a@b.com',
      createdAt: DateTime.utc(2026, 7, 1),
    );
    expect(plain.packSize, isNull);
    expect(EntryEntity.fromMap(plain.id, plain.toMap()), plain);

    final sized = EntryEntity(
      id: EntryEntity.buildId('c1', 's1', 'i1', packSize: 5),
      cycleId: 'c1',
      itemId: 'i1',
      itemName: 'Zanahoria',
      shopId: 's1',
      quantity: 2,
      notes: null,
      bought: false,
      createdBy: 'a@b.com',
      createdAt: DateTime.utc(2026, 7, 1),
      packSize: 5,
    );
    expect(sized.packSize, 5);
    expect(EntryEntity.fromMap(sized.id, sized.toMap()), sized);
  });

  test('EntryEntity.buildId keeps the plain scheme unchanged and formats sizes without trailing .0', () {
    expect(EntryEntity.buildId('c1', 's1', 'i1'), 'c1_s1_i1');
    expect(EntryEntity.buildId('c1', 's1', 'i1', packSize: 5), 'c1_s1_i1_5');
    expect(EntryEntity.buildId('c1', 's1', 'i1', packSize: 2.5), 'c1_s1_i1_2.5');
  });

  test('a shop can hold entries for two sizes of the same item at once (distinct ids)', () {
    final id5 = EntryEntity.buildId('c1', 's1', 'i1', packSize: 5);
    final id10 = EntryEntity.buildId('c1', 's1', 'i1', packSize: 10);
    expect(id5, isNot(id10));
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

  test('CycleEntity round-trips hiddenAt through toMap/fromMap', () {
    final c = CycleEntity(
      id: 'c1',
      status: CycleStatus.completed,
      openedAt: DateTime.utc(2026, 7, 1, 8),
      completedAt: DateTime.utc(2026, 7, 1, 20),
      hiddenAt: DateTime.utc(2026, 7, 2, 9),
    );
    final back = CycleEntity.fromMap('c1', c.toMap());
    expect(back.hiddenAt, DateTime.utc(2026, 7, 2, 9));
  });

  test('CycleEntity.fromMap treats missing hiddenAt as null', () {
    final map = {
      'status': 'completed',
      'openedAt': DateTime.utc(2026, 7, 1).toIso8601String(),
      'completedAt': DateTime.utc(2026, 7, 1).toIso8601String(),
    };
    expect(CycleEntity.fromMap('c1', map).hiddenAt, isNull);
  });
}
