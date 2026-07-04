import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../domain/entities/catalog_item_entity.dart';
import '../../../domain/entities/entry_entity.dart';
import '../../../domain/entities/shop_entity.dart';
import '../../providers/entry_providers.dart';
import '../../providers/firebase_auth_provider.dart';
import '../../providers/entry_view_mode_provider.dart';
import '../../providers/management_providers.dart';
import '../../widgets/data_error_retry.dart';
import '../../widgets/entry_item_controls.dart';
import '../../widgets/swipe_entry_deck.dart';

/// Lets the admin add needed quantities on behalf of a specific shop, or apply
/// the same quantity to ALL active shops at once. Complements member entry.
class AdminEntryPage extends ConsumerStatefulWidget {
  const AdminEntryPage({super.key});

  @override
  ConsumerState<AdminEntryPage> createState() => _AdminEntryPageState();
}

class _AdminEntryPageState extends ConsumerState<AdminEntryPage> {
  static const allShops = '__ALL__';
  String _target = allShops;
  String _search = '';

  /// Local, session-only override of the number shown per item (used for the
  /// "All shops" bulk mode and for immediate feedback).
  final Map<String, int> _local = {};

  @override
  Widget build(BuildContext context) {
    final member = ref.watch(authControllerProvider).member;
    final shops = (ref.watch(shopsProvider).valueOrNull ?? const <ShopEntity>[])
        .where((s) => s.active)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final catalogAsync = ref.watch(catalogProvider);

    // Current quantities to prefill the grid so the admin can see what is
    // already in the list and reduce it to 0 to remove it.
    final Map<String, int> liveQty;
    if (_target == allShops) {
      // Across all shops, show the highest quantity any shop currently needs.
      final all = ref.watch(openCycleEntriesProvider).valueOrNull ??
          const <EntryEntity>[];
      final m = <String, int>{};
      for (final e in all) {
        final cur = m[e.itemId] ?? 0;
        if (e.quantity > cur) m[e.itemId] = e.quantity;
      }
      liveQty = m;
    } else {
      final liveEntries = ref.watch(shopEntriesProvider(_target)).valueOrNull ??
          const <EntryEntity>[];
      liveQty = {for (final e in liveEntries) e.itemId: e.quantity};
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.adminEntryTitle),
        actions: [
          EntryViewMenu(
            mode: ref.watch(entryViewModeProvider),
            onChanged: (m) => ref.read(entryViewModeProvider.notifier).set(m),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: DropdownButtonFormField<String>(
              initialValue: _target,
              decoration: InputDecoration(
                labelText: context.l10n.adminEntryAddForLabel,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                DropdownMenuItem(
                    value: allShops, child: Text(context.l10n.adminEntryAllShops)),
                for (final s in shops)
                  DropdownMenuItem(value: s.id, child: Text('${s.name} (${s.code})')),
              ],
              onChanged: (v) => setState(() {
                _target = v ?? allShops;
                _local.clear();
              }),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: context.l10n.addItemSearchHint,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: catalogAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => DataErrorRetry(onRetry: () => refreshAppData(ref)),
              data: (catalog) =>
                  _grid(context, catalog, liveQty, shops, member?.id ?? ''),
            ),
          ),
        ],
      ),
    );
  }

  Widget _grid(BuildContext context, List<CatalogItemEntity> catalog,
      Map<String, int> liveQty, List<ShopEntity> shops, String memberId) {
    // Flat list in catalog (paper) order.
    final items = catalog
        .where((c) => c.active)
        .where((c) => _search.isEmpty || c.name.toLowerCase().contains(_search))
        .toList();

    Future<void> set(CatalogItemEntity item, int q) async {
      setState(() => _local[item.id] = q);
      await ref.read(entryActionsProvider).submitQuantityToShops(
            shopIds: _target == allShops
                ? [for (final s in shops) s.id]
                : [_target],
            itemId: item.id,
            itemName: item.name,
            quantity: q,
            createdBy: memberId,
          );
    }

    int qtyOf(CatalogItemEntity item) => _local[item.id] ?? liveQty[item.id] ?? 0;
    final view = ref.watch(entryViewModeProvider);

    if (view == EntryViewMode.swipe) {
      return SwipeEntryDeck(
        items: items,
        qtyByItem: {for (final it in items) it.id: qtyOf(it)},
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
            final q = qtyOf(item);
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
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final item = items[i];
          final q = qtyOf(item);
          return ListTile(
            dense: true,
            title: Text(item.name),
            trailing: EntryQtyStepper(
              qty: q,
              onDecrement: q > 0 ? () => set(item, q - 1) : null,
              onIncrement: () => set(item, q + 1),
            ),
          );
        },
      ),
    );
  }
}
