import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../l10n/app_localizations.dart';
import '../../../data/pdf/shopping_pdf_service.dart';
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

    return cyclesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => DataErrorRetry(onRetry: () => refreshAppData(ref)),
      data: (cycles) {
        if (cycles.isEmpty) {
          return Center(child: Text(context.l10n.adminHistoryEmpty));
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.print),
                      label: Text(context.l10n.adminHistoryPrintAllCombined),
                      onPressed: () => _printAllCombined(context, ref, cycles),
                    ),
                  ),
                  if (isAdmin) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline),
                      label: Text(context.l10n.adminHistoryClearAll),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                      onPressed: () => _confirmClearAll(context, ref),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [for (final c in cycles) _cycleCard(context, ref, c, isAdmin)],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _cycleCard(
      BuildContext context, WidgetRef ref, CycleEntity c, bool isAdmin) {
    final df =
        DateFormat('EEE, d MMM yyyy • HH:mm', context.l10n.localeName);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ExpansionTile(
        leading: const Icon(Icons.history),
        title: Text(df.format((c.completedAt ?? c.openedAt).toLocal())),
        trailing: _printMenu(context, ref, c.id, isAdmin),
        children: [
          FutureBuilder<List<EntryEntity>>(
            future: ref.read(entryRepositoryProvider).getByCycle(c.id),
            builder: (context, snap) {
              final entries = snap.data ?? const <EntryEntity>[];
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: LinearProgressIndicator(),
                );
              }
              return Column(
                children: [
                  for (final e in entries)
                    ListTile(
                      dense: true,
                      title: Text(e.itemName),
                      trailing: Text('${e.quantity}'),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _printMenu(
      BuildContext context, WidgetRef ref, String cycleId, bool isAdmin) {
    final shops = (ref.watch(shopsProvider).valueOrNull ?? const <ShopEntity>[])
        .where((s) => s.active)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      tooltip: context.l10n.adminHistoryPrintTooltip,
      onSelected: (value) {
        if (value == 'delete') {
          _confirmDeleteCycle(context, ref, cycleId);
        } else if (value == 'combined') {
          _printCycleCombined(context, ref, cycleId);
        } else {
          _printCycleShop(context, ref, cycleId, value);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
            value: 'combined', child: Text(context.l10n.printCombinedAllShops)),
        const PopupMenuDivider(),
        for (final s in shops)
          PopupMenuItem(
              value: s.id, child: Text(context.l10n.printShopListItem(s.name))),
        if (isAdmin) ...[
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
      BuildContext context, WidgetRef ref, String cycleId) {
    return runPrint(context, (svc, l10n) async {
      final entries = await ref.read(entryRepositoryProvider).getByCycle(cycleId);
      return _buildCombined(ref, svc, l10n, entries);
    }, name: 'greenchain-history-combined.pdf');
  }

  Future<void> _printAllCombined(
      BuildContext context, WidgetRef ref, List<CycleEntity> cycles) {
    return runPrint(context, (svc, l10n) async {
      final repo = ref.read(entryRepositoryProvider);
      final all = <EntryEntity>[];
      for (final c in cycles) {
        all.addAll(await repo.getByCycle(c.id));
      }
      return _buildCombined(ref, svc, l10n, all);
    }, name: 'greenchain-history-all.pdf');
  }

  /// Builds a combined paper grid from a set of entries (summed by item+shop,
  /// so aggregating multiple cycles works).
  Future<Uint8List> _buildCombined(WidgetRef ref, ShoppingPdfService svc,
      AppLocalizations l10n, List<EntryEntity> entries) async {
    final catalog = await ref.read(catalogProvider.future);
    final shops = (await ref.read(shopsProvider.future))
        .where((s) => s.active)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final qty = <String, Map<String, int>>{};
    for (final e in entries) {
      final byShop = qty.putIfAbsent(e.itemId, () => {});
      byShop[e.shopId] = (byShop[e.shopId] ?? 0) + e.quantity;
    }
    return svc.adminFullGrid(
      date: DateTime.now(),
      shops: shops,
      catalog: catalog,
      qtyByItemShop: qty,
      l10n: l10n,
    );
  }

  Future<void> _printCycleShop(
      BuildContext context, WidgetRef ref, String cycleId, String shopId) {
    return runPrint(context, (svc, l10n) async {
      final entries = await ref.read(entryRepositoryProvider).getByCycle(cycleId);
      final shops = await ref.read(shopsProvider.future);
      final catalog = await ref.read(catalogProvider.future);
      final shop = shops.firstWhere((s) => s.id == shopId,
          orElse: () => shops.isEmpty
              ? const ShopEntity(id: '', name: 'Shop', code: '', sortOrder: 0, active: true)
              : shops.first);
      final qtyByItem = <String, int>{};
      for (final e in entries.where((e) => e.shopId == shopId)) {
        qtyByItem[e.itemId] = (qtyByItem[e.itemId] ?? 0) + e.quantity;
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

  Future<void> _confirmDeleteCycle(
      BuildContext context, WidgetRef ref, String cycleId) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.adminHistoryDeleteConfirmTitle),
        content: Text(l10n.adminHistoryDeleteConfirmBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.delete)),
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
              child: Text(l10n.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.delete)),
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
