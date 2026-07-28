import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../domain/entities/catalog_item_entity.dart';
import '../../../domain/entities/entry_entity.dart';
import '../../../domain/entities/shop_entity.dart';
import '../../providers/entry_providers.dart';
import '../../providers/firebase_auth_provider.dart';
import '../../providers/entry_view_mode_provider.dart';
import '../../providers/show_item_images_provider.dart';
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
  final Map<String, double> _local = {};
  final Map<String, FocusNode> _qtyFocus = {};
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  final _deckKey = GlobalKey<SwipeEntryDeckState>();

  FocusNode _focusFor(String id) => _qtyFocus.putIfAbsent(id, FocusNode.new);

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final node in _qtyFocus.values) {
      node.dispose();
    }
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final member = ref.watch(authControllerProvider).member;
    final shops =
        (ref.watch(shopsProvider).valueOrNull ?? const <ShopEntity>[])
            .where((s) => s.active)
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final catalogAsync = ref.watch(catalogProvider);
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final view = ref.watch(entryViewModeProvider);

    // Current quantities to prefill the grid so the admin can see what is
    // already in the list and reduce it to 0 to remove it.
    final Map<String, double> liveQty;
    if (_target == allShops) {
      // Across all shops, show the highest quantity any shop currently needs.
      final all =
          ref.watch(openCycleEntriesProvider).valueOrNull ??
          const <EntryEntity>[];
      final m = <String, double>{};
      for (final e in all) {
        final cur = m[e.itemId] ?? 0;
        if (e.quantity > cur) m[e.itemId] = e.quantity;
      }
      liveQty = m;
    } else {
      final liveEntries =
          ref.watch(shopEntriesProvider(_target)).valueOrNull ??
          const <EntryEntity>[];
      liveQty = {for (final e in liveEntries) e.itemId: e.quantity};
    }

    return Scaffold(
      appBar: keyboardOpen
          ? null
          : AppBar(
              title: Text(context.l10n.adminEntryTitle),
              actions: [
                EntryViewMenu(
                  mode: view,
                  onChanged: (m) =>
                      ref.read(entryViewModeProvider.notifier).set(m),
                ),
              ],
            ),
      body: SafeArea(
        child: Column(
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
                    value: allShops,
                    child: Text(context.l10n.adminEntryAllShops),
                  ),
                  for (final s in shops)
                    DropdownMenuItem(
                      value: s.id,
                      child: Text('${s.name} (${s.code})'),
                    ),
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
                controller: _searchCtrl,
                focusNode: _searchFocus,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: context.l10n.addItemSearchHint,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) =>
                    setState(() => _search = v.trim().toLowerCase()),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: catalogAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) =>
                          DataErrorRetry(onRetry: () => refreshAppData(ref)),
                      data: (catalog) => _grid(
                        context,
                        catalog,
                        liveQty,
                        shops,
                        member?.id ?? '',
                      ),
                    ),
                  ),
                  if (view == EntryViewMode.swipe &&
                      _searchFocus.hasFocus &&
                      _search.isNotEmpty)
                    Positioned(
                      top: 0,
                      left: 16,
                      right: 16,
                      child: _searchSuggestions(
                        catalogAsync.valueOrNull ?? const [],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _grid(
    BuildContext context,
    List<CatalogItemEntity> catalog,
    Map<String, double> liveQty,
    List<ShopEntity> shops,
    String memberId,
  ) {
    // Flat list in catalog (paper) order.
    final items = catalog
        .where((c) => c.active)
        .where((c) => _search.isEmpty || c.name.toLowerCase().contains(_search))
        .toList();

    Future<void> set(CatalogItemEntity item, double q) async {
      setState(() => _local[item.id] = q);
      await ref
          .read(entryActionsProvider)
          .submitQuantityToShops(
            shopIds: _target == allShops
                ? [for (final s in shops) s.id]
                : [_target],
            itemId: item.id,
            itemName: item.name,
            quantity: q,
            createdBy: memberId,
          );
    }

    double qtyOf(CatalogItemEntity item) =>
        _local[item.id] ?? liveQty[item.id] ?? 0;

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
      // Swipe mode always shows the FULL active catalog: filtering it by
      // _search would shrink the deck's item list out from under its
      // internal index, which breaks the deck (jumps to "all reviewed").
      // Search instead surfaces a tappable suggestions overlay that jumps
      // the deck to the matching card.
      final allItems = catalog.where((c) => c.active).toList();
      final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
      return SwipeEntryDeck(
        key: _deckKey,
        items: allItems,
        qtyByItem: {for (final it in allItems) it.id: qtyOf(it)},
        onSet: (item, q) => set(item, q),
        showImages: ref.watch(showItemImagesProvider).valueOrNull ?? false,
        compact: keyboardOpen,
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
              onDecrement: q > 0
                  ? () =>
                        set(item, (q - 1).clamp(0, double.infinity).toDouble())
                  : null,
              onIncrement: () => set(item, q + 1),
              focusNode: _focusFor(item.id),
              onQtyEntered: (v) => set(item, v),
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
          final q = qtyOf(item);
          return ListTile(
            dense: true,
            title: Text(item.name),
            trailing: EntryQtyStepper(
              qty: q,
              onDecrement: q > 0
                  ? () =>
                        set(item, (q - 1).clamp(0, double.infinity).toDouble())
                  : null,
              onIncrement: () => set(item, q + 1),
              focusNode: _focusFor(item.id),
              onQtyEntered: (v) => set(item, v),
              onNext: () => focusNext(item.id),
            ),
          );
        },
      ),
    );
  }

  Widget _searchSuggestions(List<CatalogItemEntity> catalog) {
    final matches = catalog
        .where((c) => c.active && c.name.toLowerCase().contains(_search))
        .take(8)
        .toList();
    if (matches.isEmpty) return const SizedBox.shrink();
    // TextFieldTapRegion: taps here must count as "inside" the search field,
    // otherwise pointer-down unfocuses it, the overlay (gated on hasFocus) is
    // torn down mid-gesture, and the ListTile's onTap never fires.
    return TextFieldTapRegion(
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: matches.length,
            itemBuilder: (context, i) {
              final it = matches[i];
              return ListTile(
                dense: true,
                leading: const Icon(Icons.search, size: 18),
                title: Text(it.name),
                onTap: () {
                  _deckKey.currentState?.jumpToItem(it.id);
                  _searchCtrl.clear();
                  // Close the search keyboard so the selected card is visible
                  // right away (on mobile the custom keypad takes over; on
                  // desktop jumpToItem moves focus to the qty field anyway).
                  _searchFocus.unfocus();
                  setState(() => _search = '');
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
