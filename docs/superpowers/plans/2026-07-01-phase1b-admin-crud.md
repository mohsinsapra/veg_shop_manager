# Phase 1b — Admin Management Screens (Shops / Catalog / Members) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the admin real in-app management of Shops, Catalog items, and Members (create/edit/activate) backed by Firestore, replacing the temporary post-login landing with an admin home shell.

**Architecture:** Extend the existing clean architecture. Repositories gain create/update/soft-delete methods (hardened with lowercase-email normalization). Riverpod `StreamProvider`s expose live lists. Three management screens render those streams and write through the repositories. An `AdminHomePage` with responsive navigation (NavigationRail on wide, Drawer on narrow) routes between sections; `AuthGate` sends admins there and non-admins to the existing landing (member entry UI is Phase 2).

**Tech Stack:** Flutter 3.41 / Dart, Firebase (Firestore), Riverpod, `uuid` for new ids. Tests use `fake_cloud_firestore` + `flutter_test` with `ProviderScope` overrides.

## Global Constraints

- Flutter 3.41.5 / Dart SDK `>=3.8.1`.
- Firestore collections: `shops`, `catalogItems`, `members`, `cycles`, `entries`.
- Member docs keyed by lowercased email; `id` and `email` always lowercased on write.
- Soft delete only: set `active=false`, never hard-delete shops/catalog/members.
- New `shops`/`catalogItems` ids come from `uuid` v4; member ids are the lowercased email.
- Only admins reach these screens (enforced in-app; Firestore rules already enforce writes).
- Commit after every task with message prefix `feature/cloud-inventory-printing:`.
- New production files under `lib/`; tests mirror the path under `test/`.
- `git add` only the files a task creates/edits — never `git add -A` (the tree has pre-existing unrelated deleted paths).

---

## File Structure

- `lib/data/repositories/shop_repository.dart` — MODIFY: add `delete` not needed; keep `setActive`.
- `lib/data/repositories/catalog_repository.dart` — MODIFY: add `setActive`.
- `lib/data/repositories/member_repository.dart` — MODIFY: lowercase-normalize `upsert`; add `setActive`.
- `lib/presentation/providers/management_providers.dart` — CREATE: repo + stream providers.
- `lib/presentation/pages/admin/admin_home_page.dart` — CREATE: responsive nav shell.
- `lib/presentation/pages/admin/shops_management_page.dart` — CREATE.
- `lib/presentation/pages/admin/catalog_management_page.dart` — CREATE.
- `lib/presentation/pages/admin/members_management_page.dart` — CREATE.
- `lib/presentation/pages/auth/auth_gate.dart` — MODIFY: admin → AdminHomePage.
- Tests mirror each under `test/`.

Note: the legacy `lib/presentation/pages/admin/admin_page.dart` / `debug_admin_page.dart` / `shopping_history_page.dart` belong to the old Hive app and are NOT used by the new flow. Do not modify or wire them in this phase.

---

### Task 1: Repository hardening + soft-delete methods

**Files:**
- Modify: `lib/data/repositories/member_repository.dart`
- Modify: `lib/data/repositories/catalog_repository.dart`
- Test: `test/data/repositories/management_repos_test.dart`

**Interfaces:**
- Produces:
  - `MemberRepository.upsert(MemberEntity)` — now writes to `doc(member.id.toLowerCase())` and stores a lowercased `email` (via the entity's existing `toMap()` which already lowercases email; also normalize the doc id).
  - `MemberRepository.setActive(String id, bool active)` → `Future<void>`.
  - `CatalogRepository.setActive(String id, bool active)` → `Future<void>`.

- [ ] **Step 1: Write the failing test** `test/data/repositories/management_repos_test.dart`

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veg_shop_manager/data/datasources/remote/firestore_refs.dart';
import 'package:veg_shop_manager/data/repositories/catalog_repository.dart';
import 'package:veg_shop_manager/data/repositories/member_repository.dart';
import 'package:veg_shop_manager/domain/entities/catalog_item_entity.dart';
import 'package:veg_shop_manager/domain/entities/member_entity.dart';

void main() {
  late FirestoreRefs refs;
  setUp(() => refs = FirestoreRefs(FakeFirebaseFirestore()));

  test('MemberRepository.upsert lowercases the doc id so findByEmail matches', () async {
    final repo = MemberRepository(refs);
    await repo.upsert(const MemberEntity(
      id: 'Ana@X.com', email: 'Ana@X.com', displayName: 'Ana',
      role: MemberRole.member, shopIds: ['s1'], active: true, uid: null));
    // stored under lowercased id -> findByEmail (which lowercases) resolves it
    final found = await repo.findByEmail('ana@x.com');
    expect(found?.displayName, 'Ana');
    expect(found?.email, 'ana@x.com');
  });

  test('MemberRepository.setActive toggles active only', () async {
    final repo = MemberRepository(refs);
    await repo.upsert(const MemberEntity(
      id: 'ana@x.com', email: 'ana@x.com', displayName: 'Ana',
      role: MemberRole.member, shopIds: ['s1'], active: true, uid: null));
    await repo.setActive('ana@x.com', false);
    expect((await repo.findByEmail('ana@x.com'))?.active, false);
  });

  test('CatalogRepository.setActive toggles active', () async {
    final repo = CatalogRepository(refs);
    await repo.upsert(const CatalogItemEntity(
      id: 'i1', name: 'Apio', category: 'Vegetables', sortOrder: 0, active: true));
    await repo.setActive('i1', false);
    final items = await repo.watchAll().first;
    expect(items.single.active, false);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/repositories/management_repos_test.dart`
Expected: FAIL — `setActive` missing / id not lowercased.

- [ ] **Step 3: Update `MemberRepository`** — normalize id and add `setActive`

Replace the `upsert` method and add `setActive`:

```dart
  Future<void> upsert(MemberEntity member) =>
      _refs.members.doc(member.id.toLowerCase()).set(member.toMap());

  Future<void> setActive(String id, bool active) =>
      _refs.members.doc(id.toLowerCase()).update({'active': active});
```

(The entity's `toMap()` already lowercases `email`, so the stored doc is fully normalized.)

- [ ] **Step 4: Add `setActive` to `CatalogRepository`**

```dart
  Future<void> setActive(String id, bool active) =>
      _refs.catalogItems.doc(id).update({'active': active});
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/data/repositories/management_repos_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/data/repositories/member_repository.dart lib/data/repositories/catalog_repository.dart test/data/repositories/management_repos_test.dart
git commit -m "feature/cloud-inventory-printing: harden member upsert + add catalog/member setActive"
```

---

### Task 2: Management providers (repos + live streams)

**Files:**
- Create: `lib/presentation/providers/management_providers.dart`
- Test: `test/presentation/providers/management_providers_test.dart`

**Interfaces:**
- Consumes: `firestoreRefsProvider` (from `firebase_providers.dart`), `memberRepositoryProvider` (from `firebase_auth_provider.dart`).
- Produces:
  - `shopRepositoryProvider` → `Provider<ShopRepository>`
  - `catalogRepositoryProvider` → `Provider<CatalogRepository>`
  - `shopsProvider` → `StreamProvider<List<ShopEntity>>` (all shops incl inactive, by sortOrder)
  - `catalogProvider` → `StreamProvider<List<CatalogItemEntity>>`
  - `membersProvider` → `StreamProvider<List<MemberEntity>>`

- [ ] **Step 1: Write the failing test** `test/presentation/providers/management_providers_test.dart`

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veg_shop_manager/data/repositories/shop_repository.dart';
import 'package:veg_shop_manager/data/datasources/remote/firestore_refs.dart';
import 'package:veg_shop_manager/domain/entities/shop_entity.dart';
import 'package:veg_shop_manager/presentation/providers/firebase_providers.dart';
import 'package:veg_shop_manager/presentation/providers/management_providers.dart';

void main() {
  test('shopsProvider streams shops from Firestore', () async {
    final fake = FakeFirebaseFirestore();
    await ShopRepository(FirestoreRefs(fake)).upsert(const ShopEntity(
      id: 's1', name: 'Downtown', code: 'D', sortOrder: 0, active: true));
    final container = ProviderContainer(overrides: [
      firebaseFirestoreProvider.overrideWithValue(fake),
    ]);
    addTearDown(container.dispose);

    final shops = await container.read(shopsProvider.future);
    expect(shops.single.code, 'D');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/presentation/providers/management_providers_test.dart`
Expected: FAIL — `management_providers.dart` missing.

- [ ] **Step 3: Create `lib/presentation/providers/management_providers.dart`**

```dart
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/presentation/providers/management_providers_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/providers/management_providers.dart test/presentation/providers/management_providers_test.dart
git commit -m "feature/cloud-inventory-printing: add management repo + stream providers"
```

---

### Task 3: Admin home shell + AuthGate routing

**Files:**
- Create: `lib/presentation/pages/admin/admin_home_page.dart`
- Modify: `lib/presentation/pages/auth/auth_gate.dart`
- Test: `test/presentation/pages/admin_home_page_test.dart`

**Interfaces:**
- Consumes: `authControllerProvider` (for sign-out + member name).
- Produces: `AdminHomePage` — a `StatefulWidget` holding a selected-section index, rendering `ShopsManagementPage`, `CatalogManagementPage`, `MembersManagementPage` (Task 4-6) via a responsive nav shell. Since those pages arrive in later tasks, Task 3 renders titled placeholders that Tasks 4-6 replace.

- [ ] **Step 1: Write the failing test** `test/presentation/pages/admin_home_page_test.dart`

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veg_shop_manager/presentation/pages/admin/admin_home_page.dart';
import 'package:veg_shop_manager/presentation/providers/firebase_providers.dart';

void main() {
  testWidgets('AdminHomePage shows navigation destinations', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        firebaseAuthProvider.overrideWithValue(MockFirebaseAuth()),
        firebaseFirestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
      ],
      child: const MaterialApp(home: AdminHomePage()),
    ));
    await tester.pump();
    expect(find.text('Shops'), findsWidgets);
    expect(find.text('Catalog'), findsWidgets);
    expect(find.text('Members'), findsWidgets);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/presentation/pages/admin_home_page_test.dart`
Expected: FAIL — `admin_home_page.dart` missing.

- [ ] **Step 3: Create `lib/presentation/pages/admin/admin_home_page.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/firebase_auth_provider.dart';
import 'shops_management_page.dart';
import 'catalog_management_page.dart';
import 'members_management_page.dart';

class AdminHomePage extends ConsumerStatefulWidget {
  const AdminHomePage({super.key});

  @override
  ConsumerState<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends ConsumerState<AdminHomePage> {
  int _index = 0;

  static const _titles = ['Shops', 'Catalog', 'Members'];
  static const _icons = [Icons.store, Icons.eco, Icons.people];

  Widget _body() {
    switch (_index) {
      case 0:
        return const ShopsManagementPage();
      case 1:
        return const CatalogManagementPage();
      default:
        return const MembersManagementPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 720;
    return Scaffold(
      appBar: AppBar(
        title: Text('GreenChain — ${_titles[_index]}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: Row(
        children: [
          if (wide)
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (var i = 0; i < _titles.length; i++)
                  NavigationRailDestination(
                    icon: Icon(_icons[i]),
                    label: Text(_titles[i]),
                  ),
              ],
            ),
          Expanded(child: _body()),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                for (var i = 0; i < _titles.length; i++)
                  NavigationDestination(
                    icon: Icon(_icons[i]),
                    label: _titles[i],
                  ),
              ],
            ),
    );
  }
}
```

- [ ] **Step 4: Point `AuthGate` admins at `AdminHomePage`**

In `lib/presentation/pages/auth/auth_gate.dart`, add `import '../admin/admin_home_page.dart';` and change the `signedIn` case:

```dart
      case AuthStatus.signedIn:
        return session.isAdmin
            ? const AdminHomePage()
            : const HomeLandingPage();
```

- [ ] **Step 5: Run test to verify it passes**

Note: Tasks 4-6 create the three management pages this file imports. Until they exist, create minimal stubs first so this task compiles, OR implement Task 3 after 4-6. Chosen order: implement Tasks 4-6 pages BEFORE running this test. If running Task 3 first, add temporary stub widgets named `ShopsManagementPage`/`CatalogManagementPage`/`MembersManagementPage` returning `Center(child: Text(<title>))` and replace them in Tasks 4-6.

Run: `flutter test test/presentation/pages/admin_home_page_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/pages/admin/admin_home_page.dart lib/presentation/pages/auth/auth_gate.dart test/presentation/pages/admin_home_page_test.dart
git commit -m "feature/cloud-inventory-printing: add responsive admin home shell + admin routing"
```

---

### Task 4: Shops management screen

**Files:**
- Create: `lib/presentation/pages/admin/shops_management_page.dart`
- Test: `test/presentation/pages/shops_management_page_test.dart`

**Interfaces:**
- Consumes: `shopsProvider`, `shopRepositoryProvider` (Task 2), `ShopEntity`, `uuid`.
- Produces: `ShopsManagementPage` — lists shops from `shopsProvider`, FAB opens an add dialog, each row has edit + active toggle.

- [ ] **Step 1: Write the failing test** `test/presentation/pages/shops_management_page_test.dart`

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veg_shop_manager/data/datasources/remote/firestore_refs.dart';
import 'package:veg_shop_manager/data/repositories/shop_repository.dart';
import 'package:veg_shop_manager/domain/entities/shop_entity.dart';
import 'package:veg_shop_manager/presentation/providers/firebase_providers.dart';
import 'package:veg_shop_manager/presentation/pages/admin/shops_management_page.dart';

void main() {
  testWidgets('ShopsManagementPage lists shops', (tester) async {
    final fake = FakeFirebaseFirestore();
    await ShopRepository(FirestoreRefs(fake)).upsert(const ShopEntity(
      id: 's1', name: 'Downtown', code: 'D', sortOrder: 0, active: true));
    await tester.pumpWidget(ProviderScope(
      overrides: [firebaseFirestoreProvider.overrideWithValue(fake)],
      child: const MaterialApp(home: Scaffold(body: ShopsManagementPage())),
    ));
    await tester.pump();
    expect(find.text('Downtown'), findsOneWidget);
    expect(find.text('D'), findsWidgets);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/presentation/pages/shops_management_page_test.dart`
Expected: FAIL — page missing.

- [ ] **Step 3: Create `lib/presentation/pages/admin/shops_management_page.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../domain/entities/shop_entity.dart';
import '../../providers/management_providers.dart';

class ShopsManagementPage extends ConsumerWidget {
  const ShopsManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopsAsync = ref.watch(shopsProvider);
    return Scaffold(
      body: shopsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (shops) => ListView(
          children: [
            for (final shop in shops)
              ListTile(
                leading: CircleAvatar(child: Text(shop.code)),
                title: Text(shop.name),
                subtitle: Text('Code: ${shop.code}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: shop.active,
                      onChanged: (v) => ref
                          .read(shopRepositoryProvider)
                          .setActive(shop.id, v),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showEditDialog(context, ref, shop),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(context, ref, null),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, ShopEntity? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final codeCtrl = TextEditingController(text: existing?.code ?? '');
    final formKey = GlobalKey<FormState>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Add Shop' : 'Edit Shop'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
              ),
              TextFormField(
                controller: codeCtrl,
                decoration:
                    const InputDecoration(labelText: 'Code (grid column, e.g. D)'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a code' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final repo = ref.read(shopRepositoryProvider);
              final shop = ShopEntity(
                id: existing?.id ?? const Uuid().v4(),
                name: nameCtrl.text.trim(),
                code: codeCtrl.text.trim().toUpperCase(),
                sortOrder: existing?.sortOrder ?? 9999,
                active: existing?.active ?? true,
              );
              await repo.upsert(shop);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/presentation/pages/shops_management_page_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/pages/admin/shops_management_page.dart test/presentation/pages/shops_management_page_test.dart
git commit -m "feature/cloud-inventory-printing: add shops management screen"
```

---

### Task 5: Catalog management screen

**Files:**
- Create: `lib/presentation/pages/admin/catalog_management_page.dart`
- Test: `test/presentation/pages/catalog_management_page_test.dart`

**Interfaces:**
- Consumes: `catalogProvider`, `catalogRepositoryProvider`, `CatalogItemEntity`, `uuid`.
- Produces: `CatalogManagementPage` — items grouped by category, add/edit dialog (name + category), active toggle.

- [ ] **Step 1: Write the failing test** `test/presentation/pages/catalog_management_page_test.dart`

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veg_shop_manager/data/datasources/remote/firestore_refs.dart';
import 'package:veg_shop_manager/data/repositories/catalog_repository.dart';
import 'package:veg_shop_manager/domain/entities/catalog_item_entity.dart';
import 'package:veg_shop_manager/presentation/providers/firebase_providers.dart';
import 'package:veg_shop_manager/presentation/pages/admin/catalog_management_page.dart';

void main() {
  testWidgets('CatalogManagementPage lists items by category', (tester) async {
    final fake = FakeFirebaseFirestore();
    await CatalogRepository(FirestoreRefs(fake)).upsert(const CatalogItemEntity(
      id: 'i1', name: 'Aguacate', category: 'Vegetables', sortOrder: 0, active: true));
    await tester.pumpWidget(ProviderScope(
      overrides: [firebaseFirestoreProvider.overrideWithValue(fake)],
      child: const MaterialApp(home: Scaffold(body: CatalogManagementPage())),
    ));
    await tester.pump();
    expect(find.text('Aguacate'), findsOneWidget);
    expect(find.text('Vegetables'), findsWidgets);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/presentation/pages/catalog_management_page_test.dart`
Expected: FAIL — page missing.

- [ ] **Step 3: Create `lib/presentation/pages/admin/catalog_management_page.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../domain/entities/catalog_item_entity.dart';
import '../../providers/management_providers.dart';

class CatalogManagementPage extends ConsumerWidget {
  const CatalogManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(catalogProvider);
    return Scaffold(
      body: catalogAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          final categories = <String, List<CatalogItemEntity>>{};
          for (final it in items) {
            categories.putIfAbsent(it.category, () => []).add(it);
          }
          return ListView(
            children: [
              for (final entry in categories.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(entry.key,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                for (final item in entry.value)
                  ListTile(
                    dense: true,
                    title: Text(item.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: item.active,
                          onChanged: (v) => ref
                              .read(catalogRepositoryProvider)
                              .setActive(item.id, v),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showEditDialog(context, ref, item),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(context, ref, null),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showEditDialog(
      BuildContext context, WidgetRef ref, CatalogItemEntity? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final catCtrl = TextEditingController(text: existing?.category ?? '');
    final formKey = GlobalKey<FormState>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Add Item' : 'Edit Item'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
              ),
              TextFormField(
                controller: catCtrl,
                decoration: const InputDecoration(labelText: 'Category'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a category' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final repo = ref.read(catalogRepositoryProvider);
              final item = CatalogItemEntity(
                id: existing?.id ?? const Uuid().v4(),
                name: nameCtrl.text.trim(),
                category: catCtrl.text.trim(),
                sortOrder: existing?.sortOrder ?? 9999,
                active: existing?.active ?? true,
              );
              await repo.upsert(item);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/presentation/pages/catalog_management_page_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/pages/admin/catalog_management_page.dart test/presentation/pages/catalog_management_page_test.dart
git commit -m "feature/cloud-inventory-printing: add catalog management screen"
```

---

### Task 6: Members management screen

**Files:**
- Create: `lib/presentation/pages/admin/members_management_page.dart`
- Test: `test/presentation/pages/members_management_page_test.dart`

**Interfaces:**
- Consumes: `membersProvider`, `memberRepositoryProvider` (from `firebase_auth_provider.dart`), `shopsProvider`, `MemberEntity`, `MemberRole`.
- Produces: `MembersManagementPage` — lists members, add/edit dialog (email, displayName, role dropdown, shop multi-select from `shopsProvider`, active), active toggle. Member id = lowercased email (email is read-only when editing an existing member).

- [ ] **Step 1: Write the failing test** `test/presentation/pages/members_management_page_test.dart`

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veg_shop_manager/data/datasources/remote/firestore_refs.dart';
import 'package:veg_shop_manager/data/repositories/member_repository.dart';
import 'package:veg_shop_manager/domain/entities/member_entity.dart';
import 'package:veg_shop_manager/presentation/providers/firebase_providers.dart';
import 'package:veg_shop_manager/presentation/pages/admin/members_management_page.dart';

void main() {
  testWidgets('MembersManagementPage lists members', (tester) async {
    final fake = FakeFirebaseFirestore();
    await MemberRepository(FirestoreRefs(fake)).upsert(const MemberEntity(
      id: 'ana@x.com', email: 'ana@x.com', displayName: 'Ana',
      role: MemberRole.member, shopIds: ['s1'], active: true, uid: null));
    await tester.pumpWidget(ProviderScope(
      overrides: [firebaseFirestoreProvider.overrideWithValue(fake)],
      child: const MaterialApp(home: Scaffold(body: MembersManagementPage())),
    ));
    await tester.pump();
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('ana@x.com'), findsWidgets);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/presentation/pages/members_management_page_test.dart`
Expected: FAIL — page missing.

- [ ] **Step 3: Create `lib/presentation/pages/admin/members_management_page.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/member_entity.dart';
import '../../../domain/entities/shop_entity.dart';
import '../../providers/firebase_auth_provider.dart';
import '../../providers/management_providers.dart';

class MembersManagementPage extends ConsumerWidget {
  const MembersManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(membersProvider);
    return Scaffold(
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (members) => ListView(
          children: [
            for (final m in members)
              ListTile(
                leading: CircleAvatar(
                  child: Icon(m.isAdmin ? Icons.shield : Icons.person),
                ),
                title: Text(m.displayName),
                subtitle: Text('${m.email} • ${m.role.name}'
                    '${m.shopIds.isEmpty ? '' : ' • ${m.shopIds.length} shop(s)'}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: m.active,
                      onChanged: (v) =>
                          ref.read(memberRepositoryProvider).setActive(m.id, v),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showEditDialog(context, ref, m),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(context, ref, null),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, MemberEntity? existing) {
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final nameCtrl = TextEditingController(text: existing?.displayName ?? '');
    var role = existing?.role ?? MemberRole.member;
    final selectedShops = {...?existing?.shopIds};
    final formKey = GlobalKey<FormState>();
    final shops = ref.read(shopsProvider).valueOrNull ?? const <ShopEntity>[];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(existing == null ? 'Add Member' : 'Edit Member'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: emailCtrl,
                    enabled: existing == null, // id is the email; immutable on edit
                    decoration: const InputDecoration(labelText: 'Google email'),
                    validator: (v) =>
                        (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                  ),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Display name'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
                  ),
                  DropdownButtonFormField<MemberRole>(
                    initialValue: role,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: const [
                      DropdownMenuItem(value: MemberRole.member, child: Text('member')),
                      DropdownMenuItem(value: MemberRole.admin, child: Text('admin')),
                    ],
                    onChanged: (v) => setState(() => role = v ?? MemberRole.member),
                  ),
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Shops'),
                  ),
                  for (final s in shops)
                    CheckboxListTile(
                      dense: true,
                      title: Text('${s.name} (${s.code})'),
                      value: selectedShops.contains(s.id),
                      onChanged: (checked) => setState(() {
                        if (checked == true) {
                          selectedShops.add(s.id);
                        } else {
                          selectedShops.remove(s.id);
                        }
                      }),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final email = emailCtrl.text.trim().toLowerCase();
                final member = MemberEntity(
                  id: existing?.id ?? email,
                  email: email,
                  displayName: nameCtrl.text.trim(),
                  role: role,
                  shopIds: selectedShops.toList(),
                  active: existing?.active ?? true,
                  uid: existing?.uid,
                );
                await ref.read(memberRepositoryProvider).upsert(member);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/presentation/pages/members_management_page_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/pages/admin/members_management_page.dart test/presentation/pages/members_management_page_test.dart
git commit -m "feature/cloud-inventory-printing: add members management screen"
```

---

### Task 7: Integration verification

- [ ] **Step 1: Analyze + full test suite**

Run: `flutter analyze lib` (expect no new errors in Phase 1b files) and
`flutter test test/domain test/data test/presentation` (all green).

- [ ] **Step 2: Web build**

Run: `flutter build web` — expect `✓ Built build/web`.

- [ ] **Step 3: Manual smoke (optional, needs the running app)**

Serve `build/web`, sign in as the admin, and confirm the nav shell shows Shops/Catalog/Members with live data, add/edit dialogs write to Firestore, and the active toggle works.

- [ ] **Step 4: Commit any fixes**

```bash
git add -A -- lib test
git commit -m "feature/cloud-inventory-printing: phase 1b integration fixes"
```

---

## Self-Review Notes

- **Spec coverage:** Admin management of Shops (T4), Catalog (T5), Members with email/role/shops (T6); responsive admin shell (T3); providers (T2); the deferred hardening — lowercase `upsert` normalization (T1). Shop switcher for members and the admin pivot-grid dashboard remain Phase 2 (member entry UI). PDF and full responsive polish remain Phase 3.
- **Ordering note:** Task 3 imports the pages from Tasks 4-6. Implement 4→5→6→3, or add temporary stubs in Task 3 (called out in Task 3 Step 5). The controller executing this plan should build the three pages before wiring `AdminHomePage`.
- **Type consistency:** `shopRepositoryProvider`/`catalogRepositoryProvider`/`shopsProvider`/`catalogProvider`/`membersProvider` (Task 2) are used consistently in Tasks 4-6; `memberRepositoryProvider` comes from `firebase_auth_provider.dart` (do not redefine it). `setActive` signatures match Task 1.
- **Soft delete:** no hard deletes; `active=false` everywhere, consistent with rules and history retention.
