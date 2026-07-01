# Clear / Delete History (Admin) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let an admin soft-delete a single completed cycle or clear all history on the History page, so hidden cycles no longer appear in the list or in printing.

**Architecture:** Add a nullable `hiddenAt` timestamp to `CycleEntity`. Hidden cycles are excluded client-side in `CycleRepository.watchCompleted`. Two new repository methods mark one or all completed cycles hidden. The History page gains admin-gated delete affordances with confirm dialogs.

**Tech Stack:** Flutter, Riverpod, Cloud Firestore (`cloud_firestore`), `fake_cloud_firestore` for tests, Flutter gen-l10n (ARB) for i18n.

## Global Constraints

- Timestamps are stored in Firestore as **UTC ISO-8601 strings** (`toUtc().toIso8601String()`), matching `openedAt`/`completedAt` — NOT Firestore `Timestamp`.
- A cycle is "hidden" iff `hiddenAt != null`.
- All user-facing strings MUST be localized via `context.l10n.*` with keys added to **both** `lib/l10n/app_en.arb` and `lib/l10n/app_es.arb`.
- Admin gating uses `ref.watch(authControllerProvider).isAdmin`.
- After editing ARB files, regenerate localizations with `flutter gen-l10n`.
- Commit message prefix (matches branch convention): `feature/cloud-inventory-printing: <summary>`.
- Do NOT add AI attribution trailers to commits.
- Do NOT touch the orphaned legacy `shopping_history_page.dart`.

---

### Task 1: Add `hiddenAt` to `CycleEntity`

**Files:**
- Modify: `lib/domain/entities/cycle_entity.dart`
- Test: `test/domain/entities/entities_serialization_test.dart`

**Interfaces:**
- Produces: `CycleEntity({required id, required status, required openedAt, required completedAt, DateTime? hiddenAt})`; `CycleEntity.hiddenAt` (`DateTime?`); `toMap()` writes `'hiddenAt'` as UTC ISO-8601 string or `null`; `CycleEntity.fromMap` reads `'hiddenAt'` (absent/null → `null`).

- [ ] **Step 1: Write the failing test**

Add to `test/domain/entities/entities_serialization_test.dart` (inside `main()`):

```dart
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
```

Ensure the file imports `CycleEntity` (add `import 'package:veg_shop_manager/domain/entities/cycle_entity.dart';` if not already present).

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/entities/entities_serialization_test.dart`
Expected: FAIL — `CycleEntity` has no named parameter `hiddenAt` / getter `hiddenAt` undefined.

- [ ] **Step 3: Write minimal implementation**

Replace the body of `lib/domain/entities/cycle_entity.dart` with:

```dart
enum CycleStatus { open, completed }

class CycleEntity {
  final String id;
  final CycleStatus status;
  final DateTime openedAt;
  final DateTime? completedAt;
  final DateTime? hiddenAt;

  const CycleEntity({
    required this.id,
    required this.status,
    required this.openedAt,
    required this.completedAt,
    this.hiddenAt,
  });

  Map<String, dynamic> toMap() => {
        'status': status.name,
        'openedAt': openedAt.toUtc().toIso8601String(),
        'completedAt': completedAt?.toUtc().toIso8601String(),
        'hiddenAt': hiddenAt?.toUtc().toIso8601String(),
      };

  factory CycleEntity.fromMap(String id, Map<String, dynamic> map) => CycleEntity(
        id: id,
        status: (map['status'] as String?) == 'completed'
            ? CycleStatus.completed
            : CycleStatus.open,
        openedAt: DateTime.parse(map['openedAt'] as String).toUtc(),
        completedAt: map['completedAt'] == null
            ? null
            : DateTime.parse(map['completedAt'] as String).toUtc(),
        hiddenAt: map['hiddenAt'] == null
            ? null
            : DateTime.parse(map['hiddenAt'] as String).toUtc(),
      );

  @override
  bool operator ==(Object other) =>
      other is CycleEntity &&
      other.id == id &&
      other.status == status &&
      other.openedAt == openedAt &&
      other.completedAt == completedAt &&
      other.hiddenAt == hiddenAt;

  @override
  int get hashCode =>
      Object.hash(id, status, openedAt, completedAt, hiddenAt);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/domain/entities/entities_serialization_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/entities/cycle_entity.dart test/domain/entities/entities_serialization_test.dart
git commit -m "feature/cloud-inventory-printing: add hiddenAt to CycleEntity"
```

---

### Task 2: Repository — hide one, hide all, exclude hidden from reads

**Files:**
- Modify: `lib/data/repositories/cycle_repository.dart`
- Test: `test/data/repositories/entry_cycle_test.dart`

**Interfaces:**
- Consumes: `CycleEntity.hiddenAt`, `FirestoreRefs.cycles`, `FirestoreRefs.db` (Firestore instance for batching).
- Produces:
  - `Future<void> hideCycle(String cycleId)` — sets `hiddenAt` on one cycle to now (UTC ISO string).
  - `Future<void> hideAllCompleted()` — sets `hiddenAt` on every completed, not-yet-hidden cycle, batched (≤ 500 writes per batch).
  - `watchCompleted()` now emits only cycles with `hiddenAt == null`.

- [ ] **Step 1: Write the failing tests**

Add to `test/data/repositories/entry_cycle_test.dart` (inside `main()`):

```dart
test('hideCycle removes a cycle from watchCompleted', () async {
  final repo = CycleRepository(refs);
  final c = await repo.ensureOpenCycle(now);
  await repo.completeCycle(c.id, now);
  expect((await repo.watchCompleted().first).length, 1);

  await repo.hideCycle(c.id);
  expect(await repo.watchCompleted().first, isEmpty);
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
  expect(await repo.watchCompleted().first, isEmpty);
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/data/repositories/entry_cycle_test.dart`
Expected: FAIL — `hideCycle`/`hideAllCompleted` not defined on `CycleRepository`.

- [ ] **Step 3: Write minimal implementation**

In `lib/data/repositories/cycle_repository.dart`, change `watchCompleted` to filter out hidden cycles, and add the two methods. Replace the existing `watchCompleted` method with:

```dart
  Stream<List<CycleEntity>> watchCompleted() => retryingSnapshots(() => _refs
      .cycles
      .where('status', isEqualTo: 'completed')
      .snapshots()
      .map((snap) => (snap.docs
          .map((d) => CycleEntity.fromMap(d.id, d.data()))
          .where((c) => c.hiddenAt == null)
          .toList()
        ..sort((a, b) => (b.completedAt ?? b.openedAt)
            .compareTo(a.completedAt ?? a.openedAt)))));

  Future<void> hideCycle(String cycleId) =>
      _refs.cycles.doc(cycleId).update({
        'hiddenAt': DateTime.now().toUtc().toIso8601String(),
      });

  Future<void> hideAllCompleted() async {
    final now = DateTime.now().toUtc().toIso8601String();
    final snap =
        await _refs.cycles.where('status', isEqualTo: 'completed').get();
    final toHide =
        snap.docs.where((d) => d.data()['hiddenAt'] == null).toList();
    for (var i = 0; i < toHide.length; i += 500) {
      final batch = _refs.db.batch();
      for (final d in toHide.skip(i).take(500)) {
        batch.update(d.reference, {'hiddenAt': now});
      }
      await batch.commit();
    }
  }
```

If `FirestoreRefs` does not expose `db` and `cycles` as used above, open `lib/data/datasources/remote/firestore_refs.dart` and confirm the getter names; the exploration reports `.cycles`, `.entries`, and `.db` exist. Use `.db.batch()` for batching.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/data/repositories/entry_cycle_test.dart`
Expected: PASS (all tests, including the pre-existing ones).

- [ ] **Step 5: Commit**

```bash
git add lib/data/repositories/cycle_repository.dart test/data/repositories/entry_cycle_test.dart
git commit -m "feature/cloud-inventory-printing: hide cycle(s) + exclude hidden from history"
```

---

### Task 3: Localization strings

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_es.arb`

**Interfaces:**
- Produces l10n getters: `adminHistoryDeleteCycle`, `adminHistoryDeleteConfirmTitle`, `adminHistoryDeleteConfirmBody`, `adminHistoryClearAll`, `adminHistoryClearAllConfirmTitle`, `adminHistoryClearAllConfirmBody`, `adminHistoryClearAllSuccess`. Reuses existing `cancel` and `delete`.

- [ ] **Step 1: Add keys to `app_en.arb`**

Insert these entries into `lib/l10n/app_en.arb` (before the final closing `}`; ensure the preceding entry ends with a comma):

```json
  "adminHistoryDeleteCycle": "Delete this history",
  "adminHistoryDeleteConfirmTitle": "Delete history entry?",
  "adminHistoryDeleteConfirmBody": "This history entry will be hidden and no longer appear in the list. This cannot be undone from the app.",
  "adminHistoryClearAll": "Clear all history",
  "adminHistoryClearAllConfirmTitle": "Clear all history?",
  "adminHistoryClearAllConfirmBody": "All completed shopping history will be hidden and no longer appear. This cannot be undone from the app.",
  "adminHistoryClearAllSuccess": "History cleared"
```

- [ ] **Step 2: Add the same keys to `app_es.arb`**

Insert into `lib/l10n/app_es.arb` (before the final closing `}`; ensure the preceding entry ends with a comma):

```json
  "adminHistoryDeleteCycle": "Eliminar este historial",
  "adminHistoryDeleteConfirmTitle": "¿Eliminar entrada del historial?",
  "adminHistoryDeleteConfirmBody": "Esta entrada del historial se ocultará y dejará de aparecer en la lista. Esta acción no se puede deshacer desde la aplicación.",
  "adminHistoryClearAll": "Borrar todo el historial",
  "adminHistoryClearAllConfirmTitle": "¿Borrar todo el historial?",
  "adminHistoryClearAllConfirmBody": "Todo el historial de compras completado se ocultará y dejará de aparecer. Esta acción no se puede deshacer desde la aplicación.",
  "adminHistoryClearAllSuccess": "Historial borrado"
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: completes with no errors; `lib/l10n/app_localizations*.dart` now contain the new getters.

- [ ] **Step 4: Verify generation**

Run: `flutter analyze lib/l10n`
Expected: No new errors.

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/app_en.arb lib/l10n/app_es.arb lib/l10n/app_localizations*.dart
git commit -m "feature/cloud-inventory-printing: i18n strings for clear/delete history"
```

---

### Task 4: History page UI — admin-gated delete + clear all

**Files:**
- Modify: `lib/presentation/pages/admin/history_page.dart`

**Interfaces:**
- Consumes: `cycleRepositoryProvider` (from `entry_providers.dart`), `authControllerProvider` (from `firebase_auth_provider.dart`), `CycleRepository.hideCycle`, `CycleRepository.hideAllCompleted`, l10n getters from Task 3.

- [ ] **Step 1: Add the import for the auth provider**

At the top of `lib/presentation/pages/admin/history_page.dart`, add alongside the other provider imports:

```dart
import '../../providers/firebase_auth_provider.dart';
```

- [ ] **Step 2: Read admin state and add the "Clear all history" header button**

In `build`, after `final cyclesAsync = ref.watch(completedCyclesProvider);`, add:

```dart
    final isAdmin = ref.watch(authControllerProvider).isAdmin;
```

Then, in the `data:` branch, replace the header `Padding` (the one wrapping the "Print all" `OutlinedButton.icon`) with a `Row` that also shows a clear-all button for admins:

```dart
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.print),
                      label: Text(context.l10n.adminHistoryPrintAllCombined),
                      onPressed: () => _printAllCombined(context, ref, cycles),
                    ),
                  ),
                  if (isAdmin) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline),
                      label: Text(context.l10n.adminHistoryClearAll),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                      onPressed: () => _confirmClearAll(context, ref),
                    ),
                  ],
                ],
              ),
            ),
```

- [ ] **Step 3: Pass `isAdmin` into the cycle card and add a delete menu item**

Change the card builder call in the `ListView` to pass `isAdmin`:

```dart
                children: [for (final c in cycles) _cycleCard(context, ref, c, isAdmin)],
```

Update `_cycleCard`'s signature and its `trailing` to pass `isAdmin` down to the menu:

```dart
  Widget _cycleCard(
      BuildContext context, WidgetRef ref, CycleEntity c, bool isAdmin) {
```

and

```dart
        trailing: _printMenu(context, ref, c.id, isAdmin),
```

Update `_printMenu` to accept `isAdmin`, handle a `'delete'` selection, and append a delete item for admins:

```dart
  Widget _printMenu(
      BuildContext context, WidgetRef ref, String cycleId, bool isAdmin) {
    final shops = (ref.watch(shopsProvider).valueOrNull ?? const <ShopEntity>[])
        .where((s) => s.active)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      tooltip: context.l10n.adminHistoryPrintTooltip,
      onSelected: (value) {
        if (value == 'delete') {
          _confirmDeleteCycle(context, ref, cycleId);
        } else if (value == 'combined') {
          _printCycleCombined(context, ref, cycleId);
        } else {
          _printCycleShop(context, ref, cycleId, value);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
            value: 'combined', child: Text(context.l10n.printCombinedAllShops)),
        const PopupMenuDivider(),
        for (final s in shops)
          PopupMenuItem(
              value: s.id, child: Text(context.l10n.printShopListItem(s.name))),
        if (isAdmin) ...[
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'delete',
            child: Text(
              context.l10n.adminHistoryDeleteCycle,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ],
    );
  }
```

- [ ] **Step 4: Add the confirm + action helper methods**

Add these methods inside the `HistoryPage` class (e.g. after `_printCycleShop`):

```dart
  Future<void> _confirmDeleteCycle(
      BuildContext context, WidgetRef ref, String cycleId) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.adminHistoryDeleteConfirmTitle),
        content: Text(l10n.adminHistoryDeleteConfirmBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.delete)),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(cycleRepositoryProvider).hideCycle(cycleId);
  }

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.adminHistoryClearAllConfirmTitle),
        content: Text(l10n.adminHistoryClearAllConfirmBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.delete)),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(cycleRepositoryProvider).hideAllCompleted();
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.adminHistoryClearAllSuccess)),
    );
  }
```

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/presentation/pages/admin/history_page.dart`
Expected: No errors. (Note: the menu icon changed from `Icons.print` to `Icons.more_vert` since it now hosts delete too — this is intentional.)

- [ ] **Step 6: Run the full test suite**

Run: `flutter test`
Expected: All tests pass (no regressions from the entity/repository changes).

- [ ] **Step 7: Commit**

```bash
git add lib/presentation/pages/admin/history_page.dart
git commit -m "feature/cloud-inventory-printing: admin clear-all + per-cycle delete on history page"
```

---

## Manual verification (after all tasks)

1. Run the app (`flutter run`), sign in as an **admin**.
2. Open the History tab. Confirm each cycle's trailing menu now has a "Delete this history" item, and a red "Clear all history" button appears in the header.
3. Delete one cycle → confirm dialog → it disappears from the list. Reopen the app; it stays gone.
4. Tap "Clear all history" → confirm → list empties, success snackbar shows, and the empty state (`adminHistoryEmpty`) appears. Reopen the app; still empty.
5. Confirm "Print all history" no longer includes hidden cycles.
6. Sign in as a **non-admin** (member): no "Clear all history" button, no "Delete this history" menu item.
7. Toggle locale to Spanish and confirm all new strings are translated.

## Self-Review Notes

- **Spec coverage:** hiddenAt field (Task 1) ✓; hideCycle/hideAllCompleted + read filter (Task 2) ✓; provider filter — handled in `watchCompleted` which backs `completedCyclesProvider`, so no separate provider edit needed ✓; admin gating + confirm dialogs + UI (Task 4) ✓; i18n both ARBs (Task 3) ✓; print excludes hidden — automatic since `_printAllCombined` receives the already-filtered `cycles` list ✓; legacy page untouched ✓; no restore/hard-delete ✓.
- **Type consistency:** `hideCycle(String)`, `hideAllCompleted()`, `CycleEntity(..., DateTime? hiddenAt)` used consistently across tasks.
- **Note:** The design mentioned filtering in `completedCyclesProvider`; implementing the filter inside `watchCompleted` (its data source) is equivalent and DRY — it also fixes the print path in one place.
