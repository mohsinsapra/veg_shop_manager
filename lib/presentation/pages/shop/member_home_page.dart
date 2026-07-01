import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/pdf/shopping_pdf_service.dart';
import '../../../domain/entities/catalog_item_entity.dart';
import '../../../domain/entities/entry_entity.dart';
import '../../../domain/entities/shop_entity.dart';
import '../../pdf/print_helpers.dart';
import '../../providers/entry_providers.dart';
import '../../providers/firebase_auth_provider.dart';
import '../../providers/management_providers.dart';

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
          PopupMenuButton<bool>(
            icon: const Icon(Icons.print),
            tooltip: 'Print',
            onSelected: (fullSheet) => _print(fullSheet),
            itemBuilder: (context) => const [
              PopupMenuItem(value: false, child: Text('Print my list')),
              PopupMenuItem(value: true, child: Text('Print full sheet')),
            ],
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
        error: (e, _) => Center(child: Text('Error: $e')),
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
                  error: (e, _) => Center(child: Text('Error: $e')),
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

  Future<void> _print(bool fullSheet) async {
    final shopId = _shopId;
    if (shopId == null) return;
    final shops = ref.read(shopsProvider).valueOrNull ?? const <ShopEntity>[];
    final shop = shops.firstWhere((s) => s.id == shopId,
        orElse: () => shops.isEmpty
            ? const ShopEntity(id: '', name: 'Shop', code: '', sortOrder: 0, active: true)
            : shops.first);
    final catalog = await ref.read(catalogProvider.future);
    final entries = await ref.read(shopEntriesProvider(shopId).future);
    final qtyByItem = {for (final e in entries) e.itemId: e.quantity};
    if (!mounted) return;
    await runPrint(
      context,
      (svc) => fullSheet
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
            ),
      name: 'greenchain-${shop.code}.pdf',
    );
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

  Widget _grid(BuildContext context, ShopEntity shop,
      List<CatalogItemEntity> catalog, String memberId) {
    final entriesAsync = ref.watch(shopEntriesProvider(shop.id));
    final entries = entriesAsync.valueOrNull ?? const <EntryEntity>[];
    final qtyByItem = {for (final e in entries) e.itemId: e.quantity};

    final items = catalog
        .where((c) => c.active)
        .where((c) => _search.isEmpty || c.name.toLowerCase().contains(_search))
        .toList();

    final byCategory = <String, List<CatalogItemEntity>>{};
    for (final it in items) {
      byCategory.putIfAbsent(it.category, () => []).add(it);
    }

    return ListView(
      children: [
        for (final entry in byCategory.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(entry.key,
                style: Theme.of(context).textTheme.titleMedium),
          ),
          for (final item in entry.value)
            _row(shop.id, item, qtyByItem[item.id] ?? 0, memberId),
        ],
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _row(String shopId, CatalogItemEntity item, int qty, String memberId) {
    Future<void> set(int q) => ref.read(entryActionsProvider).submitQuantity(
          shopId: shopId,
          itemId: item.id,
          itemName: item.name,
          quantity: q,
          createdBy: memberId,
        );

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
