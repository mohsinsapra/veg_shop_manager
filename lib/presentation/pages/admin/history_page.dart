import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/utils/qty_format.dart';
import '../../../l10n/app_localizations.dart';
import '../../../data/pdf/shopping_pdf_service.dart';
import '../../../domain/entities/catalog_item_entity.dart';
import '../../../domain/entities/cycle_entity.dart';
import '../../../domain/entities/entry_entity.dart';
import '../../../domain/entities/shop_entity.dart';
import '../../pdf/print_helpers.dart';
import '../../providers/entry_providers.dart';
import '../../providers/firebase_auth_provider.dart';
import '../../providers/management_providers.dart';
import '../../widgets/data_error_retry.dart';

/// Completed shopping cycles, most recent first. Each can be printed (combined
/// grid or per-shop), and all history can be printed as one combined grid.
class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cyclesAsync = ref.watch(completedCyclesProvider);
    final isAdmin = ref.watch(authControllerProvider).isAdmin;
    final memberEmail = ref.watch(authControllerProvider).member?.email;
    final isOwner = memberEmail?.toLowerCase() == AppConstants.ownerEmail;

    return cyclesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => DataErrorRetry(onRetry: () => refreshAppData(ref)),
      data: (allCycles) {
        // Only the app owner sees hidden (soft-deleted) cycles; everyone
        // else keeps the previous behavior of never seeing them.
        final visibleCycles = isOwner
            ? allCycles
            : allCycles.where((c) => c.hiddenAt == null).toList();
        // Deleted cycles never contribute to the printed aggregate, even
        // for the owner who can still see them in the list.
        final nonHiddenCycles =
            allCycles.where((c) => c.hiddenAt == null).toList();
        if (visibleCycles.isEmpty) {
          return Center(child: Text(context.l10n.adminHistoryEmpty));
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      icon: const Icon(Icons.print_outlined, size: 20),
                      label: Text(
                        context.l10n.adminHistoryPrintAllCombined,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: () =>
                          _printAllCombined(context, ref, nonHiddenCycles),
                    ),
                  ),
                  if (isAdmin) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        label: Text(
                          context.l10n.adminHistoryClearAll,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.errorContainer,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onErrorContainer,
                        ),
                        onPressed: () => _confirmClearAll(context, ref),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 4, bottom: 16),
                children: [
                  for (final c in visibleCycles)
                    _cycleCard(context, ref, c, isAdmin, isOwner),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _cycleCard(
    BuildContext context,
    WidgetRef ref,
    CycleEntity c,
    bool isAdmin,
    bool isOwner,
  ) {
    final isHidden = c.hiddenAt != null;
    final scheme = Theme.of(context).colorScheme;
    final when = (c.completedAt ?? c.openedAt).toLocal();
    final dateStr = DateFormat(
      'EEE, d MMM yyyy',
      context.l10n.localeName,
    ).format(when);
    final timeStr = DateFormat('HH:mm', context.l10n.localeName).format(when);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: isHidden ? scheme.surfaceContainerHighest : scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          leading: Opacity(
            opacity: isHidden ? 0.5 : 1,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: isHidden
                    ? null
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          scheme.primary,
                          scheme.primary.withValues(alpha: 0.7),
                        ],
                      ),
                color: isHidden ? scheme.outline : null,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                color: scheme.onPrimary,
                size: 24,
              ),
            ),
          ),
          title: Opacity(
            opacity: isHidden ? 0.6 : 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  dateStr,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (isHidden) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      context.l10n.adminHistoryDeletedBadge,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: scheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          subtitle: Opacity(
            opacity: isHidden ? 0.6 : 1,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule, size: 14, color: scheme.outline),
                  const SizedBox(width: 4),
                  Text(
                    timeStr,
                    style: TextStyle(fontSize: 13, color: scheme.outline),
                  ),
                ],
              ),
            ),
          ),
          trailing: _printMenu(context, ref, c, isAdmin, isOwner),
          children: [
            Consumer(
              builder: (context, ref, _) {
                final entriesAsync = ref.watch(cycleEntriesProvider(c.id));
                if (entriesAsync.isLoading && !entriesAsync.hasValue) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: LinearProgressIndicator(),
                  );
                }
                final entries =
                    entriesAsync.valueOrNull ?? const <EntryEntity>[];
                return Column(
                  children: [
                    Divider(
                      height: 1,
                      color: scheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 8),
                    for (final e in entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                e.itemName,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.primaryContainer,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                fmtQty(e.quantity),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _printMenu(
    BuildContext context,
    WidgetRef ref,
    CycleEntity cycle,
    bool isAdmin,
    bool isOwner,
  ) {
    final cycleId = cycle.id;
    final isHidden = cycle.hiddenAt != null;
    final shops =
        (ref.watch(shopsProvider).valueOrNull ?? const <ShopEntity>[])
            .where((s) => s.active)
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      tooltip: context.l10n.adminHistoryPrintTooltip,
      onSelected: (value) {
        if (value == 'delete') {
          _confirmDeleteCycle(context, ref, cycleId);
        } else if (value == 'restore') {
          ref.read(cycleRepositoryProvider).unhideCycle(cycleId);
        } else if (value == 'combined') {
          _printCycleCombined(context, ref, cycleId);
        } else {
          _printCycleShop(context, ref, cycleId, value);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'combined',
          child: Text(context.l10n.printCombinedAllShops),
        ),
        const PopupMenuDivider(),
        for (final s in shops)
          PopupMenuItem(
            value: s.id,
            child: Text(context.l10n.printShopListItem(s.name)),
          ),
        if (isOwner && isHidden) ...[
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'restore',
            child: Text(context.l10n.adminHistoryRestore),
          ),
        ] else if (isAdmin) ...[
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'delete',
            child: Text(
              context.l10n.adminHistoryDeleteCycle,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ],
    );
  }

  // All data-fetching happens INSIDE runPrint's build closure so the print
  // can't silently no-op if the history list rebuilds mid-fetch.

  Future<void> _printCycleCombined(
    BuildContext context,
    WidgetRef ref,
    String cycleId,
  ) async {
    final mode = await pickGridTotalMode(context);
    if (mode == null) return;
    if (!context.mounted) return;
    return runPrint(context, (svc, l10n) async {
      final entries = await ref
          .read(entryRepositoryProvider)
          .getByCycle(cycleId);
      return _buildCombined(ref, svc, l10n, entries, mode);
    }, name: 'greenchain-history-combined.pdf');
  }

  Future<void> _printAllCombined(
    BuildContext context,
    WidgetRef ref,
    List<CycleEntity> cycles,
  ) async {
    final mode = await pickGridTotalMode(context);
    if (mode == null) return;
    if (!context.mounted) return;
    return runPrint(context, (svc, l10n) async {
      final repo = ref.read(entryRepositoryProvider);
      final lists = await Future.wait(cycles.map((c) => repo.getByCycle(c.id)));
      final all = [for (final l in lists) ...l];
      return _buildCombined(ref, svc, l10n, all, mode);
    }, name: 'greenchain-history-all.pdf');
  }

  /// Builds a combined paper grid from a set of entries (summed by item+shop,
  /// so aggregating multiple cycles works).
  Future<Uint8List> _buildCombined(
    WidgetRef ref,
    ShoppingPdfService svc,
    AppLocalizations l10n,
    List<EntryEntity> entries,
    GridTotalMode totalMode,
  ) async {
    final catalog = await ref.read(catalogProvider.future);
    final shops =
        (await ref.read(shopsProvider.future)).where((s) => s.active).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final qty = <String, Map<String, double>>{};
    for (final e in entries) {
      final id = _resolveCatalogId(e, catalog);
      if (id == null) continue;
      final byShop = qty.putIfAbsent(id, () => {});
      byShop[e.shopId] = (byShop[e.shopId] ?? 0) + e.quantity;
    }
    return svc.adminFullGrid(
      date: DateTime.now(),
      shops: shops,
      catalog: catalog,
      qtyByItemShop: qty,
      l10n: l10n,
      totalMode: totalMode,
    );
  }

  Future<void> _printCycleShop(
    BuildContext context,
    WidgetRef ref,
    String cycleId,
    String shopId,
  ) {
    return runPrint(context, (svc, l10n) async {
      final entries = await ref
          .read(entryRepositoryProvider)
          .getByCycle(cycleId);
      final shops = await ref.read(shopsProvider.future);
      final catalog = await ref.read(catalogProvider.future);
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
      final qtyByItem = <String, double>{};
      for (final e in entries.where((e) => e.shopId == shopId)) {
        final id = _resolveCatalogId(e, catalog);
        if (id == null) continue;
        qtyByItem[id] = (qtyByItem[id] ?? 0) + e.quantity;
      }
      return svc.shopSheet(
        shopName: shop.name,
        shopCode: shop.code,
        date: DateTime.now(),
        catalog: catalog,
        qtyByItem: qtyByItem,
        l10n: l10n,
      );
    }, name: 'greenchain-history-shop.pdf');
  }

  /// Maps a history entry onto the CURRENT catalog. Old cycles can hold item
  /// ids from a previous catalog seeding; those print as an empty grid when
  /// matched by id alone, so fall back to the entry's stored item name.
  String? _resolveCatalogId(EntryEntity e, List<CatalogItemEntity> catalog) {
    for (final c in catalog) {
      if (c.id == e.itemId) return e.itemId;
    }
    final name = e.itemName.trim().toLowerCase();
    for (final c in catalog) {
      if (c.name.trim().toLowerCase() == name) return c.id;
    }
    return null;
  }

  Future<void> _confirmDeleteCycle(
    BuildContext context,
    WidgetRef ref,
    String cycleId,
  ) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.adminHistoryDeleteConfirmTitle),
        content: Text(l10n.adminHistoryDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(cycleRepositoryProvider).hideCycle(cycleId);
  }

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.adminHistoryClearAllConfirmTitle),
        content: Text(l10n.adminHistoryClearAllConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(cycleRepositoryProvider).hideAllCompleted();
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.adminHistoryClearAllSuccess)),
    );
  }
}
