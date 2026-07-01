import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/entry_entity.dart';
import '../../../domain/entities/shop_entity.dart';
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
              padding: const EdgeInsets.all(12),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Text(
                'Today · ${itemNames.length} items · $boughtUnits/$totalUnits units bought',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
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
