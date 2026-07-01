import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/pdf/shopping_pdf_service.dart';
import '../../../domain/entities/cycle_entity.dart';
import '../../../domain/entities/entry_entity.dart';
import '../../../domain/entities/shop_entity.dart';
import '../../pdf/print_helpers.dart';
import '../../providers/entry_providers.dart';
import '../../providers/management_providers.dart';

/// Completed shopping cycles, most recent first. Each can be printed (combined
/// grid or per-shop), and all history can be printed as one combined grid.
class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  static final _df = DateFormat('EEE, d MMM yyyy • HH:mm');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cyclesAsync = ref.watch(completedCyclesProvider);

    return cyclesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (cycles) {
        if (cycles.isEmpty) {
          return const Center(child: Text('No completed lists yet.'));
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.print),
                label: const Text('Print all history (combined)'),
                onPressed: () => _printAllCombined(context, ref, cycles),
              ),
            ),
            Expanded(
              child: ListView(
                children: [for (final c in cycles) _cycleCard(context, ref, c)],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _cycleCard(BuildContext context, WidgetRef ref, CycleEntity c) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ExpansionTile(
        leading: const Icon(Icons.history),
        title: Text(_df.format((c.completedAt ?? c.openedAt).toLocal())),
        trailing: _printMenu(context, ref, c.id),
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

  Widget _printMenu(BuildContext context, WidgetRef ref, String cycleId) {
    final shops = (ref.watch(shopsProvider).valueOrNull ?? const <ShopEntity>[])
        .where((s) => s.active)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return PopupMenuButton<String>(
      icon: const Icon(Icons.print),
      tooltip: 'Print this list',
      onSelected: (value) => value == 'combined'
          ? _printCycleCombined(context, ref, cycleId)
          : _printCycleShop(context, ref, cycleId, value),
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'combined', child: Text('Combined grid (all shops)')),
        const PopupMenuDivider(),
        for (final s in shops)
          PopupMenuItem(value: s.id, child: Text('${s.name} list')),
      ],
    );
  }

  // All data-fetching happens INSIDE runPrint's build closure so the print
  // can't silently no-op if the history list rebuilds mid-fetch.

  Future<void> _printCycleCombined(
      BuildContext context, WidgetRef ref, String cycleId) {
    return runPrint(context, (svc) async {
      final entries = await ref.read(entryRepositoryProvider).getByCycle(cycleId);
      return _buildCombined(ref, svc, entries);
    }, name: 'greenchain-history-combined.pdf');
  }

  Future<void> _printAllCombined(
      BuildContext context, WidgetRef ref, List<CycleEntity> cycles) {
    return runPrint(context, (svc) async {
      final repo = ref.read(entryRepositoryProvider);
      final all = <EntryEntity>[];
      for (final c in cycles) {
        all.addAll(await repo.getByCycle(c.id));
      }
      return _buildCombined(ref, svc, all);
    }, name: 'greenchain-history-all.pdf');
  }

  /// Builds a combined paper grid from a set of entries (summed by item+shop,
  /// so aggregating multiple cycles works).
  Future<Uint8List> _buildCombined(
      WidgetRef ref, ShoppingPdfService svc, List<EntryEntity> entries) async {
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
    );
  }

  Future<void> _printCycleShop(
      BuildContext context, WidgetRef ref, String cycleId, String shopId) {
    return runPrint(context, (svc) async {
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
      );
    }, name: 'greenchain-history-shop.pdf');
  }
}
