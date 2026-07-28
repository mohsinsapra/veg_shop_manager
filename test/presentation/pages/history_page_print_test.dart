import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veg_shop_manager/data/pdf/shopping_pdf_service.dart';
import 'package:veg_shop_manager/domain/entities/catalog_item_entity.dart';
import 'package:veg_shop_manager/domain/entities/entry_entity.dart';
import 'package:veg_shop_manager/domain/entities/shop_entity.dart';
import 'package:veg_shop_manager/l10n/app_localizations.dart';
import 'package:veg_shop_manager/presentation/pdf/print_helpers.dart';

/// Tests for the PDF print flow's speed/feedback improvements:
///  - `runPrint` shows an immediate "preparing" SnackBar and surfaces
///    failures without crashing.
///  - `_printAllCombined`'s multi-cycle fetch runs in parallel (Future.wait)
///    instead of serially awaiting each cycle in a loop.
///
/// `HistoryPage`'s `_printCycleCombined` / `_printAllCombined` /
/// `_printCycleShop` / `_buildCombined` / `_resolveCatalogId` are all
/// private to history_page.dart, so they can't be invoked directly from this
/// file. Instead these tests exercise the *same* public building blocks the
/// page uses (`runPrint`, `ShoppingPdfService`, and — for the parallel-fetch
/// case — the exact `Future.wait(cycles.map(...))` pattern now used in
/// `_printAllCombined`) with an injected `deliver` callback that captures
/// the resulting bytes instead of handing them to the OS share/print sheet
/// (which isn't available in the widget-test environment).
void main() {
  DateTime now = DateTime(2026, 7, 28);

  List<CatalogItemEntity> buildCatalog(int count) => [
    for (var i = 0; i < count; i++)
      CatalogItemEntity(
        id: 'item$i',
        name: 'Item $i',
        category: i.isEven ? 'Verduras' : 'Frutas',
        sortOrder: i,
        active: true,
      ),
  ];

  List<ShopEntity> buildShops(int count) => [
    for (var i = 0; i < count; i++)
      ShopEntity(
        id: 'shop$i',
        name: 'Shop $i',
        code: 'S$i',
        sortOrder: i,
        active: true,
      ),
  ];

  EntryEntity entry({
    required String cycleId,
    required String shopId,
    required String itemId,
    required String itemName,
    required double quantity,
  }) => EntryEntity(
    id: EntryEntity.buildId(cycleId, shopId, itemId),
    cycleId: cycleId,
    itemId: itemId,
    itemName: itemName,
    shopId: shopId,
    quantity: quantity,
    notes: null,
    bought: false,
    createdBy: 'ana@x.com',
    createdAt: now,
  );

  /// Same catalog-id resolution `HistoryPage._resolveCatalogId` performs:
  /// match by id first, falling back to a case-insensitive name match so
  /// entries carrying stale item ids from an older catalog still resolve.
  String? resolveCatalogId(EntryEntity e, List<CatalogItemEntity> catalog) {
    for (final c in catalog) {
      if (c.id == e.itemId) return e.itemId;
    }
    final name = e.itemName.trim().toLowerCase();
    for (final c in catalog) {
      if (c.name.trim().toLowerCase() == name) return c.id;
    }
    return null;
  }

  /// Mirrors `HistoryPage._buildCombined`: sums entries by item+shop and
  /// renders the admin grid.
  Future<Uint8List> buildCombined(
    ShoppingPdfService svc,
    AppLocalizations l10n,
    List<EntryEntity> entries,
    List<CatalogItemEntity> catalog,
    List<ShopEntity> shops,
  ) {
    final qty = <String, Map<String, double>>{};
    for (final e in entries) {
      final id = resolveCatalogId(e, catalog);
      if (id == null) continue;
      final byShop = qty.putIfAbsent(id, () => {});
      byShop[e.shopId] = (byShop[e.shopId] ?? 0) + e.quantity;
    }
    return svc.adminFullGrid(
      date: now,
      shops: shops,
      catalog: catalog,
      qtyByItemShop: qty,
      l10n: l10n,
      totalMode: GridTotalMode.shopsAndTotal,
    );
  }

  /// Minimal harness: a button whose tap runs [action] with a real
  /// BuildContext (so `context.l10n` / `ScaffoldMessenger.of(context)` work
  /// exactly as they do inside HistoryPage).
  Widget harness(Future<void> Function(BuildContext context) action) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => action(context),
            child: const Text('print'),
          ),
        ),
      ),
    );
  }

  testWidgets('print combined produces a PDF with the grid', (tester) async {
    // flutter_test disables real HTTP (all requests return 400), so
    // buildPdfService's Google Fonts fetch always fails and falls back to
    // Helvetica — a much lighter font than the Unicode one used in
    // production. A generous item count keeps the rendered grid comfortably
    // above the "just a title" size regardless of which font actually
    // embeds.
    final catalog = buildCatalog(100);
    final shops = buildShops(2);
    final entries = [
      for (var i = 0; i < catalog.length; i++)
        entry(
          cycleId: 'c1',
          shopId: shops[i % shops.length].id,
          itemId: catalog[i].id,
          itemName: catalog[i].name,
          quantity: (i % 5) + 1.0,
        ),
    ];

    Uint8List? captured;
    await tester.pumpWidget(
      harness(
        (context) => runPrint(
          context,
          (svc, l10n) => buildCombined(svc, l10n, entries, catalog, shops),
          name: 'combined.pdf',
          deliver: (bytes, {String name = ''}) async {
            captured = bytes;
          },
        ),
      ),
    );

    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.length, greaterThan(5000));
  });

  testWidgets('print all combined aggregates cycles in parallel', (
    tester,
  ) async {
    final catalog = buildCatalog(100);
    final shops = buildShops(2);
    final cycleIds = ['c1', 'c2', 'c3', 'c4'];
    final entriesByCycle = {
      for (final id in cycleIds)
        id: [
          for (var i = 0; i < catalog.length; i++)
            entry(
              cycleId: id,
              shopId: shops[i % shops.length].id,
              itemId: catalog[i].id,
              itemName: catalog[i].name,
              quantity: 1,
            ),
        ],
    };

    // Records the cycle id the instant getByCycle is invoked (synchronously,
    // before the artificial delay), so we can tell parallel dispatch (all
    // ids recorded up front) apart from a serial loop (ids trickle in one
    // at a time as each prior fetch completes).
    final requested = <String>[];
    Future<List<EntryEntity>> fakeGetByCycle(String cycleId) async {
      requested.add(cycleId);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      return entriesByCycle[cycleId] ?? const [];
    }

    Uint8List? captured;
    await tester.pumpWidget(
      harness(
        (context) => runPrint(
          context,
          (svc, l10n) async {
            // Exactly the pattern `_printAllCombined` now uses.
            final lists = await Future.wait(
              cycleIds.map((id) => fakeGetByCycle(id)),
            );
            final all = [for (final l in lists) ...l];
            return buildCombined(svc, l10n, all, catalog, shops);
          },
          name: 'all.pdf',
          deliver: (bytes, {String name = ''}) async {
            captured = bytes;
          },
        ),
      ),
    );

    await tester.tap(find.byType(ElevatedButton));
    // One pump lets the synchronous portion of runPrint's build closure run:
    // Future.wait eagerly invokes fakeGetByCycle for every cycle before any
    // of them resolve, so all ids should already be recorded.
    await tester.pump();
    expect(requested, containsAll(cycleIds));
    expect(requested.length, cycleIds.length);

    await tester.pumpAndSettle();
    expect(captured, isNotNull);
    expect(captured!.length, greaterThan(5000));
  });

  testWidgets('per-shop sheet includes only that shop quantities', (
    tester,
  ) async {
    final catalog = buildCatalog(100);
    final shops = buildShops(2);
    final entries = [
      for (var i = 0; i < catalog.length; i++) ...[
        entry(
          cycleId: 'c1',
          shopId: shops[0].id,
          itemId: catalog[i].id,
          itemName: catalog[i].name,
          quantity: 2,
        ),
        entry(
          cycleId: 'c1',
          shopId: shops[1].id,
          itemId: catalog[i].id,
          itemName: catalog[i].name,
          quantity: 3,
        ),
      ],
    ];

    Uint8List? captured;
    await tester.pumpWidget(
      harness(
        (context) => runPrint(
          context,
          (svc, l10n) async {
            final qtyByItem = <String, double>{};
            for (final e in entries.where((e) => e.shopId == shops[0].id)) {
              final id = resolveCatalogId(e, catalog);
              if (id == null) continue;
              qtyByItem[id] = (qtyByItem[id] ?? 0) + e.quantity;
            }
            return svc.shopSheet(
              shopName: shops[0].name,
              shopCode: shops[0].code,
              date: now,
              catalog: catalog,
              qtyByItem: qtyByItem,
              l10n: l10n,
            );
          },
          name: 'shop.pdf',
          deliver: (bytes, {String name = ''}) async {
            captured = bytes;
          },
        ),
      ),
    );

    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    // Brief only calls for "non-trivial length" here (a single-column shop
    // sheet is inherently smaller than the multi-shop combined grid); a
    // dropped/near-empty table would be a few KB at most, so this still
    // guards against that regression without over-fitting to the exact
    // font that happens to embed in a given test environment.
    expect(captured, isNotNull);
    expect(captured!.length, greaterThan(3000));
  });

  test('shopCompact excludes zero-quantity lines (smaller PDF)', () async {
    final svc = ShoppingPdfService();
    final l10n = AppLocalizations.delegate.load(const Locale('en'));
    final localizations = await l10n;

    final allZero = [
      const PdfLine('Verduras', 'Tomate', 0),
      const PdfLine('Verduras', 'Cebolla', 0),
      const PdfLine('Frutas', 'Manzana', 0),
    ];
    final someNonZero = [
      const PdfLine('Verduras', 'Tomate', 4),
      const PdfLine('Verduras', 'Cebolla', 2),
      const PdfLine('Frutas', 'Manzana', 3),
    ];

    final zeroBytes = await svc.shopCompact(
      shopName: 'Downtown',
      date: now,
      lines: allZero,
      l10n: localizations,
    );
    final nonZeroBytes = await svc.shopCompact(
      shopName: 'Downtown',
      date: now,
      lines: someNonZero,
      l10n: localizations,
    );

    // Zero-quantity lines are filtered out (shopCompact only lists lines
    // with quantity > 0), so the all-zero PDF renders an (almost) empty
    // table and must be smaller than the one with real rows.
    expect(zeroBytes.length, lessThan(nonZeroBytes.length));
  });

  testWidgets(
    'history entries with stale item ids fall back to name matching',
    (tester) async {
      final catalog = buildCatalog(100);
      final shops = buildShops(2);

      // "Matching ids" case: itemId lines up with the catalog directly.
      final matchingEntries = [
        for (var i = 0; i < catalog.length; i++)
          entry(
            cycleId: 'c1',
            shopId: shops[i % shops.length].id,
            itemId: catalog[i].id,
            itemName: catalog[i].name,
            quantity: (i % 4) + 1.0,
          ),
      ];

      // "Stale id" case: itemId no longer exists in the catalog (as if the
      // catalog was re-seeded with new ids), but itemName still matches.
      final staleEntries = [
        for (var i = 0; i < catalog.length; i++)
          entry(
            cycleId: 'c1',
            shopId: shops[i % shops.length].id,
            itemId: 'old-catalog-id-$i',
            itemName: catalog[i].name,
            quantity: (i % 4) + 1.0,
          ),
      ];

      Future<Uint8List> capture(List<EntryEntity> entries) async {
        Uint8List? captured;
        await tester.pumpWidget(
          harness(
            (context) => runPrint(
              context,
              (svc, l10n) => buildCombined(svc, l10n, entries, catalog, shops),
              name: 'combined.pdf',
              deliver: (bytes, {String name = ''}) async {
                captured = bytes;
              },
            ),
          ),
        );
        await tester.tap(find.byType(ElevatedButton));
        await tester.pumpAndSettle();
        return captured!;
      }

      final matchingBytes = await capture(matchingEntries);
      final staleBytes = await capture(staleEntries);

      expect(matchingBytes.length, greaterThan(5000));
      // Falling back to name matching must resolve the same rows/quantities,
      // so the rendered grid is essentially the same size either way.
      expect(staleBytes.length, greaterThan(5000));
      expect(
        (staleBytes.length - matchingBytes.length).abs(),
        lessThan(matchingBytes.length * 0.05),
      );
    },
  );

  testWidgets(
    'runPrint shows a preparing snackbar then an error snackbar on failure',
    (tester) async {
      final completer = Completer<Uint8List>();
      await tester.pumpWidget(
        harness(
          (context) => runPrint(
            context,
            (svc, l10n) => completer.future,
            name: 'fails.pdf',
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      // Pump once, before the build future completes: the "preparing"
      // SnackBar must already be visible.
      await tester.pump();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Preparing PDF…'), findsOneWidget);

      completer.completeError(Exception('boom'));
      await tester.pumpAndSettle();

      // The preparing snackbar is replaced by the failure snackbar; the app
      // doesn't crash despite the thrown error.
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Print failed'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
