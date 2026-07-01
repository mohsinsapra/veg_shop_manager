import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/catalog_item_entity.dart';
import '../../../domain/entities/entry_entity.dart';
import '../../../domain/entities/shop_entity.dart';
import '../../providers/entry_providers.dart';
import '../../providers/firebase_auth_provider.dart';
import '../../providers/management_providers.dart';

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
      appBar: AppBar(title: const Text('Add items to the list')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: DropdownButtonFormField<String>(
              initialValue: _target,
              decoration: const InputDecoration(
                labelText: 'Add for',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(value: allShops, child: Text('All shops')),
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
              error: (e, _) => Center(child: Text('Error: $e')),
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

    return ListView(
      children: [
        for (final item in items)
          _row(item, _local[item.id] ?? liveQty[item.id] ?? 0, shops, memberId),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _row(CatalogItemEntity item, int qty, List<ShopEntity> shops,
      String memberId) {
    Future<void> set(int q) async {
      setState(() => _local[item.id] = q);
      final actions = ref.read(entryActionsProvider);
      final targets = _target == allShops ? shops.map((s) => s.id) : [_target];
      for (final shopId in targets) {
        await actions.submitQuantity(
          shopId: shopId,
          itemId: item.id,
          itemName: item.name,
          quantity: q,
          createdBy: memberId,
        );
      }
    }

    return ListTile(
      dense: true,
      title: Text(item.name),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: qty > 0 ? () => set(qty - 1) : null,
          ),
          SizedBox(
            width: 44,
            child: Text('$qty',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: qty > 0 ? Colors.green[800] : Colors.grey)),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => set(qty + 1),
          ),
        ],
      ),
    );
  }
}
