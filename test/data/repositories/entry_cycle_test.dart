import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veg_shop_manager/data/datasources/remote/firestore_refs.dart';
import 'package:veg_shop_manager/data/repositories/cycle_repository.dart';
import 'package:veg_shop_manager/data/repositories/entry_repository.dart';
import 'package:veg_shop_manager/domain/entities/cycle_entity.dart';

void main() {
  late FirestoreRefs refs;
  final now = DateTime.utc(2026, 7, 1);
  setUp(() => refs = FirestoreRefs(FakeFirebaseFirestore()));

  test('ensureOpenCycle creates one then reuses it', () async {
    final repo = CycleRepository(refs);
    final a = await repo.ensureOpenCycle(now);
    final b = await repo.ensureOpenCycle(now);
    expect(a.id, b.id);
    expect(a.status, CycleStatus.open);
  });

  test('completeCycle marks it completed and it appears in watchCompleted', () async {
    final repo = CycleRepository(refs);
    final c = await repo.ensureOpenCycle(now);
    await repo.completeCycle(c.id, now);
    expect(await repo.getOpenCycle(), isNull);
    final completed = await repo.watchCompleted().first;
    expect(completed.single.id, c.id);
    expect(completed.single.status, CycleStatus.completed);
  });

  test('setQuantity upserts a deterministic entry and removes on qty<=0', () async {
    final repo = EntryRepository(refs);
    await repo.setQuantity(
        cycleId: 'c1', shopId: 's1', itemId: 'i1', itemName: 'Apio',
        quantity: 5, createdBy: 'ana@x.com', now: now);
    var entries = await repo.getByCycle('c1');
    expect(entries.single.quantity, 5);
    expect(entries.single.id, 'c1_s1_i1');

    // update same (cycle,shop,item) -> still one entry, new qty
    await repo.setQuantity(
        cycleId: 'c1', shopId: 's1', itemId: 'i1', itemName: 'Apio',
        quantity: 8, createdBy: 'ana@x.com', now: now);
    entries = await repo.getByCycle('c1');
    expect(entries.length, 1);
    expect(entries.single.quantity, 8);

    // qty 0 removes it
    await repo.setQuantity(
        cycleId: 'c1', shopId: 's1', itemId: 'i1', itemName: 'Apio',
        quantity: 0, createdBy: 'ana@x.com', now: now);
    expect(await repo.getByCycle('c1'), isEmpty);
  });

  test('setQuantity preserves bought flag across quantity edits', () async {
    final repo = EntryRepository(refs);
    await repo.setQuantity(
        cycleId: 'c1', shopId: 's1', itemId: 'i1', itemName: 'Apio',
        quantity: 5, createdBy: 'ana@x.com', now: now);
    await repo.setBought('c1_s1_i1', true);
    await repo.setQuantity(
        cycleId: 'c1', shopId: 's1', itemId: 'i1', itemName: 'Apio',
        quantity: 9, createdBy: 'ana@x.com', now: now);
    final entries = await repo.getByCycle('c1');
    expect(entries.single.bought, true);
    expect(entries.single.quantity, 9);
  });

  test('hideCycle marks a cycle hidden but watchCompleted still carries it',
      () async {
    // watchCompleted no longer filters hidden cycles out itself — that's
    // now the caller's job (HistoryPage shows them only to the owner) — so
    // the repository stream must keep returning the cycle with hiddenAt set.
    final repo = CycleRepository(refs);
    final c = await repo.ensureOpenCycle(now);
    await repo.completeCycle(c.id, now);
    expect((await repo.watchCompleted().first).length, 1);
    expect((await repo.watchCompleted().first).single.hiddenAt, isNull);

    await repo.hideCycle(c.id);
    final afterHide = await repo.watchCompleted().first;
    expect(afterHide.length, 1);
    expect(afterHide.single.hiddenAt, isNotNull);
  });

  test('unhideCycle clears hiddenAt', () async {
    final repo = CycleRepository(refs);
    final c = await repo.ensureOpenCycle(now);
    await repo.completeCycle(c.id, now);
    await repo.hideCycle(c.id);
    expect((await repo.watchCompleted().first).single.hiddenAt, isNotNull);

    await repo.unhideCycle(c.id);
    expect((await repo.watchCompleted().first).single.hiddenAt, isNull);
  });

  test('hideAllCompleted hides every completed cycle', () async {
    final repo = CycleRepository(refs);
    // create + complete two cycles
    final c1 = await repo.ensureOpenCycle(now);
    await repo.completeCycle(c1.id, now);
    final c2 = await repo.ensureOpenCycle(now);
    await repo.completeCycle(c2.id, now);
    expect((await repo.watchCompleted().first).length, 2);

    await repo.hideAllCompleted();
    final afterHideAll = await repo.watchCompleted().first;
    expect(afterHideAll.length, 2);
    expect(afterHideAll.every((c) => c.hiddenAt != null), isTrue);
  });
}
