import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/utils/qty_format.dart';
import '../../../data/pdf/shopping_pdf_service.dart';
import '../../../domain/entities/catalog_item_entity.dart';
import '../../../domain/entities/entry_entity.dart';
import '../../../domain/entities/shop_entity.dart';
import '../../pdf/print_helpers.dart';
import '../../providers/entry_providers.dart';
import '../../providers/firebase_auth_provider.dart';
import '../../providers/entry_view_mode_provider.dart';
import '../../providers/show_item_images_provider.dart';
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
  final Map<String, FocusNode> _qtyFocus = {};

  // Which pack size is currently selected per sized item (list/grid views).
  final Map<String, double> _selectedSize = {};

  FocusNode _focusFor(String id) => _qtyFocus.putIfAbsent(id, FocusNode.new);

  /// The active pack size for [item] (list/grid views): the member's last
  /// selection if still valid, else the smallest size. Null for plain items.
  double? _selectedSizeFor(CatalogItemEntity item) {
    if (item.packSizes.isEmpty) return null;
    final sizes = [...item.packSizes]..sort();
    final sel = _selectedSize[item.id];
    if (sel != null && sizes.contains(sel)) return sel;
    return sizes.first;
  }

  /// Chip row (+ "2×5kg · 1×10kg" summary) for a sized item's list/grid row.
  Widget _sizeSelector(
    CatalogItemEntity item,
    double selected,
    Map<double, double> qtyBySize,
  ) {
    final sizes = [...item.packSizes]..sort();
    final unit = item.unit.isEmpty ? 'kg' : item.unit;
    final summary = sizes
        .where((s) => (qtyBySize[s] ?? 0) > 0)
        .map((s) => '${fmtQty(qtyBySize[s] ?? 0)}×${fmtQty(s)}$unit')
        .join(' · ');
    return Wrap(
      spacing: 4,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final s in sizes)
          ChoiceChip(
            label: Text('${fmtQty(s)}$unit'),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            selected: s == selected,
            onSelected: (_) => setState(() => _selectedSize[item.id] = s),
          ),
        if (summary.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              summary,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    for (final node in _qtyFocus.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final member = ref.watch(authControllerProvider).member;
    final shopsAsync = ref.watch(shopsProvider);
    final catalogAsync = ref.watch(catalogProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.memberHomeTitle),
        actions: [
          EntryViewMenu(
            mode: ref.watch(entryViewModeProvider),
            onChanged: (m) => ref.read(entryViewModeProvider.notifier).set(m),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.print),
            tooltip: context.l10n.memberPrintTooltip,
            onSelected: _print,
            itemBuilder: (context) {
              final multi =
                  (ref.read(authControllerProvider).member?.shopIds.length ??
                      0) >
                  1;
              return [
                PopupMenuItem(
                  value: 'compact',
                  child: Text(context.l10n.memberPrintMyList),
                ),
                PopupMenuItem(
                  value: 'sheet',
                  child: Text(context.l10n.memberPrintFullSheet),
                ),
                if (multi)
                  PopupMenuItem(
                    value: 'combined',
                    child: Text(context.l10n.memberPrintCombined),
                  ),
              ];
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: context.l10n.logoutTooltip,
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  context.l10n.memberNoShopAssigned,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          _shopId ??= myShops.first.id;
          final activeShop = myShops.firstWhere(
            (s) => s.id == _shopId,
            orElse: () => myShops.first,
          );

          return Column(
            children: [
              _dateBanner(context),
              _shopSelector(myShops),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: context.l10n.memberSearchItemHint,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (v) =>
                      setState(() => _search = v.trim().toLowerCase()),
                ),
              ),
              Expanded(
                child: catalogAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) =>
                      DataErrorRetry(onRetry: () => refreshAppData(ref)),
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
    GridTotalMode? totalMode;
    if (mode == 'combined') {
      totalMode = await pickGridTotalMode(context);
      if (totalMode == null) return;
    }
    if (!mounted) return;
    // Data-fetching happens inside runPrint so it can't silently no-op, and on
    // mobile the PDF is shared via the OS sheet.
    await runPrint(context, (svc, l10n) async {
      final catalog = await ref.read(catalogProvider.future);
      final shops = await ref.read(shopsProvider.future);
      final shop = shops.firstWhere(
        (s) => s.id == shopId,
        orElse: () => shops.isEmpty
            ? const ShopEntity(
                id: '',
                name: 'Shop',
                code: '',
                sortOrder: 0,
                active: true,
              )
            : shops.first,
      );

      if (mode == 'combined') {
        // Combined grid of every shop this member has access to.
        final member = ref.read(authControllerProvider).member;
        final myShopIds = member?.shopIds ?? const <String>[];
        final myShops =
            shops.where((s) => s.active && myShopIds.contains(s.id)).toList()
              ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        final allEntries = await ref.read(openCycleEntriesProvider.future);
        final qty = <String, Map<String, double>>{};
        for (final e in allEntries.where((e) => myShopIds.contains(e.shopId))) {
          (qty[itemSizeKey(e.itemId, e.packSize)] ??= {})[e.shopId] = e.quantity;
        }
        return svc.adminFullGrid(
          date: DateTime.now(),
          shops: myShops,
          catalog: catalog,
          qtyByItemShop: qty,
          l10n: l10n,
          totalMode: totalMode!,
        );
      }

      final entries = await ref.read(shopEntriesProvider(shopId).future);
      final qtyByItem = {
        for (final e in entries) itemSizeKey(e.itemId, e.packSize): e.quantity,
      };
      return mode == 'sheet'
          ? svc.shopSheet(
              shopName: shop.name,
              shopCode: shop.code,
              date: DateTime.now(),
              catalog: catalog,
              qtyByItem: qtyByItem,
              l10n: l10n,
            )
          : svc.shopCompact(
              shopName: shop.name,
              date: DateTime.now(),
              lines: [
                for (final c in catalog.where((c) => c.active))
                  if (c.packSizes.isEmpty)
                    PdfLine(c.category, c.name, qtyByItem[c.id] ?? 0)
                  else
                    for (final size in ([...c.packSizes]..sort()))
                      PdfLine(
                        c.category,
                        '${c.name} ${fmtQty(size)}${c.unit.isEmpty ? 'kg' : c.unit}',
                        qtyByItem[itemSizeKey(c.id, size)] ?? 0,
                      ),
              ],
              l10n: l10n,
            );
    }, name: 'greenchain-$mode.pdf');
  }

  Widget _shopSelector(List<ShopEntity> shops) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: DropdownButtonFormField<String>(
        initialValue: _shopId,
        decoration: InputDecoration(
          labelText: context.l10n.memberShopLabel,
          border: const OutlineInputBorder(),
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

  Widget _dateBanner(BuildContext context) {
    final cycle = ref.watch(openCycleProvider).valueOrNull;
    final date = cycle?.openedAt.toLocal() ?? DateTime.now();
    final formattedDate = DateFormat(
      'EEE, d MMM yyyy',
      context.l10n.localeName,
    ).format(date);
    final label = cycle == null
        ? context.l10n.memberNewListLabel(formattedDate)
        : context.l10n.memberListForLabel(formattedDate);
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

  Widget _grid(
    BuildContext context,
    ShopEntity shop,
    List<CatalogItemEntity> catalog,
    String memberId,
  ) {
    final entries =
        ref.watch(shopEntriesProvider(shop.id)).valueOrNull ??
        const <EntryEntity>[];
    // Plain entries (no size) key qtyByItem as before; sized entries are
    // kept separately so they never collide with each other or the base qty.
    final qtyByItem = {
      for (final e in entries)
        if (e.packSize == null) e.itemId: e.quantity,
    };
    final sizeQtyByItem = <String, Map<double, double>>{};
    for (final e in entries) {
      if (e.packSize != null) {
        (sizeQtyByItem[e.itemId] ??= {})[e.packSize!] = e.quantity;
      }
    }

    // Flat list in catalog (paper) order — the provider sorts by sortOrder,
    // which matches the paper sheet sequence.
    final items = catalog
        .where((c) => c.active)
        .where((c) => _search.isEmpty || c.name.toLowerCase().contains(_search))
        .toList();

    Future<void> set(CatalogItemEntity item, double q, {double? packSize}) =>
        ref
            .read(entryActionsProvider)
            .submitQuantity(
              shopId: shop.id,
              itemId: item.id,
              itemName: item.name,
              quantity: q,
              createdBy: memberId,
              packSize: packSize,
            );

    void focusNext(String currentItemId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final i = items.indexWhere((it) => it.id == currentItemId);
        if (i == -1) return;
        if (i + 1 < items.length) {
          _qtyFocus[items[i + 1].id]?.requestFocus();
        } else {
          _qtyFocus[currentItemId]?.unfocus();
        }
      });
    }

    final view = ref.watch(entryViewModeProvider);
    if (view == EntryViewMode.swipe) {
      return SwipeEntryDeck(
        items: items,
        qtyByItem: {for (final it in items) it.id: qtyByItem[it.id] ?? 0},
        sizeQtyByItem: {
          for (final it in items)
            if (sizeQtyByItem[it.id] != null) it.id: sizeQtyByItem[it.id]!,
        },
        onSet: (item, q, {packSize}) => set(item, q, packSize: packSize),
        showImages: ref.watch(showItemImagesProvider).valueOrNull ?? false,
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
            final size = _selectedSizeFor(item);
            final qtyBySize = sizeQtyByItem[item.id] ?? const {};
            final q = size == null ? (qtyByItem[item.id] ?? 0) : (qtyBySize[size] ?? 0);
            return EntryCard(
              name: item.name,
              qty: q,
              sizeSelector:
                  size == null ? null : _sizeSelector(item, size, qtyBySize),
              onDecrement: q > 0
                  ? () => set(item, (q - 1).clamp(0, double.infinity).toDouble(),
                      packSize: size)
                  : null,
              onIncrement: () => set(item, q + 1, packSize: size),
              focusNode: _focusFor(item.id),
              onQtyEntered: (v) => set(item, v, packSize: size),
              onNext: () => focusNext(item.id),
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
          final size = _selectedSizeFor(item);
          final qtyBySize = sizeQtyByItem[item.id] ?? const {};
          final q = size == null ? (qtyByItem[item.id] ?? 0) : (qtyBySize[size] ?? 0);
          return ListTile(
            dense: true,
            title: Text(item.name),
            subtitle: size == null ? null : _sizeSelector(item, size, qtyBySize),
            trailing: EntryQtyStepper(
              qty: q,
              onDecrement: q > 0
                  ? () => set(item, (q - 1).clamp(0, double.infinity).toDouble(),
                      packSize: size)
                  : null,
              onIncrement: () => set(item, q + 1, packSize: size),
              focusNode: _focusFor(item.id),
              onQtyEntered: (v) => set(item, v, packSize: size),
              onNext: () => focusNext(item.id),
            ),
          );
        },
      ),
    );
  }
}
