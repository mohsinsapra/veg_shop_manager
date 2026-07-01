import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:beamer/beamer.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../data/pdf/shopping_pdf_service.dart';
import '../../../domain/entities/catalog_item_entity.dart';
import '../../../domain/entities/entry_entity.dart';
import '../../../domain/entities/shop_entity.dart';
import '../../pdf/print_helpers.dart';
import '../../providers/entry_providers.dart';
import '../../providers/firebase_auth_provider.dart';
import '../../providers/entry_view_mode_provider.dart';
import '../../providers/management_providers.dart';
import '../../widgets/data_error_retry.dart';
import '../../widgets/entry_item_controls.dart';
import '../../widgets/swipe_entry_deck.dart';

/// Shop staff entry: pick the active shop, then set needed quantities for
/// catalog items (searchable grid). Members can span multiple shops.
class MemberHomePage extends ConsumerStatefulWidget {
  const MemberHomePage({super.key});

  @override
  ConsumerState<MemberHomePage> createState() => _MemberHomePageState();
}

class _MemberHomePageState extends ConsumerState<MemberHomePage> {
  String? _shopId;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final member = ref.watch(authControllerProvider).member;
    final shopsAsync = ref.watch(shopsProvider);
    final catalogAsync = ref.watch(catalogProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('GreenChain — My Shop'),
        actions: [
          EntryViewMenu(
            mode: ref.watch(entryViewModeProvider),
            onChanged: (m) => ref.read(entryViewModeProvider.notifier).set(m),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.print),
            tooltip: 'Print',
            onSelected: _print,
            itemBuilder: (context) {
              final multi = (ref.read(authControllerProvider).member?.shopIds
                          .length ??
                      0) >
                  1;
              return [
                const PopupMenuItem(value: 'compact', child: Text('Print my list')),
                const PopupMenuItem(value: 'sheet', child: Text('Print full sheet')),
                if (multi)
                  const PopupMenuItem(
                      value: 'combined',
                      child: Text('Print combined (all my shops)')),
              ];
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: context.l10n.settingsTitle,
            onPressed: () => context.beamToNamed('/settings'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: shopsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => DataErrorRetry(onRetry: () => refreshAppData(ref)),
        data: (allShops) {
          final myShopIds = member?.shopIds ?? const <String>[];
          final myShops = allShops
              .where((s) => s.active && myShopIds.contains(s.id))
              .toList();
          if (myShops.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No shop assigned to your account yet.\nAsk your admin to add you to a shop.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          _shopId ??= myShops.first.id;
          final activeShop = myShops.firstWhere((s) => s.id == _shopId,
              orElse: () => myShops.first);

          return Column(
            children: [
              _dateBanner(),
              _shopSelector(myShops),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search item…',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
                ),
              ),
              Expanded(
                child: catalogAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => DataErrorRetry(onRetry: () => refreshAppData(ref)),
                  data: (catalog) =>
                      _grid(context, activeShop, catalog, member?.id ?? ''),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _print(String mode) async {
    final shopId = _shopId;
    if (shopId == null) return;
    // Data-fetching happens inside runPrint so it can't silently no-op, and on
    // mobile the PDF is shared via the OS sheet.
    await runPrint(context, (svc) async {
      final catalog = await ref.read(catalogProvider.future);
      final shops = await ref.read(shopsProvider.future);
      final shop = shops.firstWhere((s) => s.id == shopId,
          orElse: () => shops.isEmpty
              ? const ShopEntity(id: '', name: 'Shop', code: '', sortOrder: 0, active: true)
              : shops.first);

      if (mode == 'combined') {
        // Combined grid of every shop this member has access to.
        final member = ref.read(authControllerProvider).member;
        final myShopIds = member?.shopIds ?? const <String>[];
        final myShops = shops
            .where((s) => s.active && myShopIds.contains(s.id))
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        final allEntries = await ref.read(openCycleEntriesProvider.future);
        final qty = <String, Map<String, int>>{};
        for (final e in allEntries.where((e) => myShopIds.contains(e.shopId))) {
          (qty[e.itemId] ??= {})[e.shopId] = e.quantity;
        }
        return svc.adminFullGrid(
          date: DateTime.now(),
          shops: myShops,
          catalog: catalog,
          qtyByItemShop: qty,
        );
      }

      final entries = await ref.read(shopEntriesProvider(shopId).future);
      final qtyByItem = {for (final e in entries) e.itemId: e.quantity};
      return mode == 'sheet'
          ? svc.shopSheet(
              shopName: shop.name,
              shopCode: shop.code,
              date: DateTime.now(),
              catalog: catalog,
              qtyByItem: qtyByItem,
            )
          : svc.shopCompact(
              shopName: shop.name,
              date: DateTime.now(),
              lines: [
                for (final c in catalog.where((c) => c.active))
                  PdfLine(c.category, c.name, qtyByItem[c.id] ?? 0),
              ],
            );
    }, name: 'greenchain-$mode.pdf');
  }

  Widget _shopSelector(List<ShopEntity> shops) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: DropdownButtonFormField<String>(
        initialValue: _shopId,
        decoration: const InputDecoration(
          labelText: 'Shop',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        items: [
          for (final s in shops)
            DropdownMenuItem(value: s.id, child: Text('${s.name} (${s.code})')),
        ],
        onChanged: (v) => setState(() => _shopId = v),
      ),
    );
  }

  Widget _dateBanner() {
    final cycle = ref.watch(openCycleProvider).valueOrNull;
    final date = cycle?.openedAt.toLocal() ?? DateTime.now();
    final label = cycle == null
        ? 'New list · ${DateFormat('EEE, d MMM yyyy').format(date)}'
        : 'List for ${DateFormat('EEE, d MMM yyyy').format(date)}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          const Icon(Icons.event, size: 16),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _grid(BuildContext context, ShopEntity shop,
      List<CatalogItemEntity> catalog, String memberId) {
    final entries = ref.watch(shopEntriesProvider(shop.id)).valueOrNull ??
        const <EntryEntity>[];
    final qtyByItem = {for (final e in entries) e.itemId: e.quantity};

    // Flat list in catalog (paper) order — the provider sorts by sortOrder,
    // which matches the paper sheet sequence.
    final items = catalog
        .where((c) => c.active)
        .where((c) => _search.isEmpty || c.name.toLowerCase().contains(_search))
        .toList();

    Future<void> set(CatalogItemEntity item, int q) =>
        ref.read(entryActionsProvider).submitQuantity(
              shopId: shop.id,
              itemId: item.id,
              itemName: item.name,
              quantity: q,
              createdBy: memberId,
            );

    final view = ref.watch(entryViewModeProvider);
    if (view == EntryViewMode.swipe) {
      return SwipeEntryDeck(
        items: items,
        qtyByItem: {for (final it in items) it.id: qtyByItem[it.id] ?? 0},
        onSet: (item, q) => set(item, q),
      );
    }

    if (view == EntryViewMode.grid) {
      return RefreshIndicator(
        onRefresh: () => refreshAppData(ref),
        child: GridView.builder(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 190,
            childAspectRatio: 1.05,
          ),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final item = items[i];
            final q = qtyByItem[item.id] ?? 0;
            return EntryCard(
              name: item.name,
              qty: q,
              onDecrement: q > 0 ? () => set(item, q - 1) : null,
              onIncrement: () => set(item, q + 1),
            );
          },
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => refreshAppData(ref),
      child: ListView(
        children: [
          for (final item in items)
            ListTile(
              dense: true,
              title: Text(item.name),
              trailing: EntryQtyStepper(
                qty: qtyByItem[item.id] ?? 0,
                onDecrement: (qtyByItem[item.id] ?? 0) > 0
                    ? () => set(item, (qtyByItem[item.id] ?? 0) - 1)
                    : null,
                onIncrement: () => set(item, (qtyByItem[item.id] ?? 0) + 1),
              ),
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
