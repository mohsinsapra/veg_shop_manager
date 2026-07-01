import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/pdf/shopping_pdf_service.dart';
import '../../../domain/entities/catalog_item_entity.dart';
import '../../../domain/entities/entry_entity.dart';
import '../../../domain/entities/shop_entity.dart';
import '../../pdf/print_helpers.dart';
import '../../providers/entry_providers.dart';
import '../../providers/management_providers.dart';

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

    return entriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (entries) {
        if (entries.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No items requested yet today.',
                  textAlign: TextAlign.center),
            ),
          );
        }

        final byItem = <String, List<EntryEntity>>{};
        for (final e in entries) {
          byItem.putIfAbsent(e.itemName, () => []).add(e);
        }
        final itemNames = byItem.keys.toList()..sort();

        final totalUnits =
            entries.fold<int>(0, (s, e) => s + e.quantity);
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
            if (allBought)
              Padding(
                padding: const EdgeInsets.all(8),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Complete shopping list'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white),
                  onPressed: () => _confirmComplete(context, ref),
                ),
              ),
            Expanded(
              child: ListView(
                children: [
                  for (final name in itemNames)
                    _itemTile(context, ref, name, byItem[name]!, shopName),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _itemTile(BuildContext context, WidgetRef ref, String name,
      List<EntryEntity> rows, Map<String, String> shopName) {
    final total = rows.fold<int>(0, (s, e) => s + e.quantity);
    final allBought = rows.every((e) => e.bought);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: allBought ? Colors.green.shade100 : null,
          child: Text('$total'),
        ),
        title: Text(name,
            style: TextStyle(
                decoration: allBought ? TextDecoration.lineThrough : null)),
        subtitle: Text('${rows.length} shop(s) need this'),
        children: [
          for (final e in rows)
            CheckboxListTile(
              dense: true,
              value: e.bought,
              onChanged: (v) =>
                  ref.read(entryActionsProvider).setBought(e.id, v ?? false),
              title: Text('${shopName[e.shopId] ?? e.shopId}: ${e.quantity}'),
            ),
        ],
      ),
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
      List<EntryEntity> entries, List<ShopEntity> shops) async {
    final catalog =
        ref.read(catalogProvider).valueOrNull ?? const <CatalogItemEntity>[];
    final qty = <String, Map<String, int>>{};
    for (final e in entries) {
      qty.putIfAbsent(e.itemId, () => {})[e.shopId] = e.quantity;
    }
    final svc = await buildPdfService();
    final bytes = await svc.adminFullGrid(
      date: DateTime.now(),
      shops: shops,
      catalog: catalog,
      qtyByItemShop: qty,
    );
    await printBytes(bytes, name: 'greenchain-combined.pdf');
  }

  Future<void> _printShop(BuildContext context, WidgetRef ref,
      List<EntryEntity> entries, String shopId) async {
    final shops = ref.read(shopsProvider).valueOrNull ?? const <ShopEntity>[];
    final shop = shops.firstWhere((s) => s.id == shopId,
        orElse: () => shops.isEmpty
            ? const ShopEntity(id: '', name: 'Shop', code: '', sortOrder: 0, active: true)
            : shops.first);
    final lines = [
      for (final e in entries.where((e) => e.shopId == shopId))
        PdfLine('', e.itemName, e.quantity),
    ]..sort((a, b) => a.itemName.compareTo(b.itemName));
    final svc = await buildPdfService();
    final bytes = await svc.shopCompact(
      shopName: shop.name,
      date: DateTime.now(),
      lines: lines,
    );
    await printBytes(bytes, name: 'greenchain-${shop.code}.pdf');
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
