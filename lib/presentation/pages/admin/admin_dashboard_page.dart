import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/entry_entity.dart';
import '../../../domain/entities/shop_entity.dart';
import '../../pdf/print_helpers.dart';
import '../../providers/entry_providers.dart';
import '../../providers/management_providers.dart';
import '../../widgets/data_error_retry.dart';

/// Admin combined view: items down the side, each showing the total needed
/// across shops plus a per-shop breakdown with bought toggles. This is the
/// on-screen pivot of the paper grid; PDF prints reuse the same data.
class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(openCycleEntriesProvider);
    final shops = ref.watch(shopsProvider).valueOrNull ?? const <ShopEntity>[];
    final shopName = {for (final s in shops) s.id: '${s.name} (${s.code})'};
    final catalog = ref.watch(catalogProvider).valueOrNull ?? const [];
    final orderById = {for (final c in catalog) c.id: c.sortOrder};

    return entriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => DataErrorRetry(onRetry: () => refreshAppData(ref)),
      data: (entries) {
        if (entries.isEmpty) {
          return RefreshIndicator(
            onRefresh: () => refreshAppData(ref),
            child: ListView(
              children: const [
                SizedBox(height: 160),
                Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No items requested yet today.\nTap “Add items” to start the list.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        }

        final byItem = <String, List<EntryEntity>>{};
        for (final e in entries) {
          byItem.putIfAbsent(e.itemName, () => []).add(e);
        }
        // Order the shopping list by catalog (paper) order.
        final itemNames = byItem.keys.toList()
          ..sort((a, b) {
            final sa = orderById[byItem[a]!.first.itemId] ?? 1 << 30;
            final sb = orderById[byItem[b]!.first.itemId] ?? 1 << 30;
            return sa != sb ? sa.compareTo(sb) : a.compareTo(b);
          });

        final totalUnits = entries.fold<int>(0, (s, e) => s + e.quantity);
        final boughtUnits = entries
            .where((e) => e.bought)
            .fold<int>(0, (s, e) => s + e.quantity);
        final allBought = entries.every((e) => e.bought);

        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Today · ${itemNames.length} items · $boughtUnits/$totalUnits units bought',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  _printMenu(context, ref, entries),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(allBought
                          ? Icons.remove_done
                          : Icons.done_all),
                      label: Text(allBought ? 'Unmark all' : 'Mark all bought'),
                      onPressed: () => ref
                          .read(entryActionsProvider)
                          .setBoughtBatch(entries.map((e) => e.id), !allBought),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Complete'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white),
                      onPressed: () => _confirmComplete(context, ref),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => refreshAppData(ref),
                child: ListView(
                  children: [
                    for (final name in itemNames)
                      _ItemTile(
                        name: name,
                        rows: byItem[name]!,
                        shopName: shopName,
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _printMenu(BuildContext context, WidgetRef ref, List<EntryEntity> entries) {
    final shops = (ref.watch(shopsProvider).valueOrNull ?? const <ShopEntity>[])
        .where((s) => s.active)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return PopupMenuButton<String>(
      icon: const Icon(Icons.print),
      tooltip: 'Print',
      onSelected: (value) async {
        if (value == 'combined') {
          await _printCombined(context, ref, entries, shops);
        } else {
          await _printShop(context, ref, entries, value);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'combined', child: Text('Combined grid (all shops)')),
        const PopupMenuDivider(),
        for (final s in shops)
          PopupMenuItem(value: s.id, child: Text('${s.name} list')),
      ],
    );
  }

  Future<void> _printCombined(BuildContext context, WidgetRef ref,
      List<EntryEntity> entries, List<ShopEntity> shops) {
    return runPrint(context, (svc) async {
      final catalog = await ref.read(catalogProvider.future);
      final loadedShops = (await ref.read(shopsProvider.future))
          .where((s) => s.active)
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      final qty = <String, Map<String, int>>{};
      for (final e in entries) {
        qty.putIfAbsent(e.itemId, () => {})[e.shopId] = e.quantity;
      }
      return svc.adminFullGrid(
        date: DateTime.now(),
        shops: loadedShops,
        catalog: catalog,
        qtyByItemShop: qty,
      );
    }, name: 'greenchain-combined.pdf');
  }

  Future<void> _printShop(BuildContext context, WidgetRef ref,
      List<EntryEntity> entries, String shopId) {
    return runPrint(context, (svc) async {
      final shops = await ref.read(shopsProvider.future);
      final catalog = await ref.read(catalogProvider.future);
      final shop = shops.firstWhere((s) => s.id == shopId,
          orElse: () => shops.isEmpty
              ? const ShopEntity(id: '', name: 'Shop', code: '', sortOrder: 0, active: true)
              : shops.first);
      final qtyByItem = {
        for (final e in entries.where((e) => e.shopId == shopId))
          e.itemId: e.quantity,
      };
      return svc.shopSheet(
        shopName: shop.name,
        shopCode: shop.code,
        date: DateTime.now(),
        catalog: catalog,
        qtyByItem: qtyByItem,
      );
    }, name: 'greenchain-$shopId.pdf');
  }

  void _confirmComplete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete shopping list'),
        content: const Text(
            'Move today\'s list to history and start a fresh one?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(entryActionsProvider).completeCurrentCycle();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Shopping list completed and archived.')));
              }
            },
            child: const Text('Complete'),
          ),
        ],
      ),
    );
  }
}

/// One item row: a tappable icon marks the whole item (all shops) bought;
/// tapping the body expands the per-shop breakdown with remove buttons.
class _ItemTile extends ConsumerStatefulWidget {
  final String name;
  final List<EntryEntity> rows;
  final Map<String, String> shopName;
  const _ItemTile(
      {required this.name, required this.rows, required this.shopName});

  @override
  ConsumerState<_ItemTile> createState() => _ItemTileState();
}

class _ItemTileState extends ConsumerState<_ItemTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final rows = widget.rows;
    final total = rows.fold<int>(0, (s, e) => s + e.quantity);
    final allBought = rows.every((e) => e.bought);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        children: [
          ListTile(
            leading: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => ref
                  .read(entryActionsProvider)
                  .setBoughtBatch(rows.map((e) => e.id), !allBought),
              child: Tooltip(
                message: allBought ? 'Mark not bought' : 'Mark all bought',
                child: CircleAvatar(
                  backgroundColor:
                      allBought ? Colors.green : Colors.grey.shade200,
                  child: allBought
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : Text('$total'),
                ),
              ),
            ),
            title: Text(widget.name,
                style: TextStyle(
                    decoration:
                        allBought ? TextDecoration.lineThrough : null)),
            subtitle: Text('${rows.length} shop(s) need this'),
            trailing: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded)
            for (final e in rows)
              ListTile(
                dense: true,
                leading: Checkbox(
                  value: e.bought,
                  onChanged: (v) => ref
                      .read(entryActionsProvider)
                      .setBought(e.id, v ?? false),
                ),
                title: Text(
                    '${widget.shopName[e.shopId] ?? e.shopId}: ${e.quantity}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Remove from list',
                  onPressed: () =>
                      ref.read(entryRepositoryProvider).delete(e.id),
                ),
              ),
        ],
      ),
    );
  }
}
