import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beamer/beamer.dart';
import '../../providers/auth_provider.dart';
import '../../providers/missing_item_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/date_utils.dart';
import '../../../domain/entities/missing_item_entity.dart';

final allMissingItemsProvider = FutureProvider<List<MissingItemEntity>>((ref) async {
  final allItems = await ref.watch(missingItemLocalDataSourceProvider).getAllMissingItems();
  return allItems.map((item) => MissingItemEntity(
    id: item.id,
    itemName: item.itemName,
    quantity: item.quantity,
    shopId: item.shopId,
    date: item.date,
    notes: item.notes,
  )).toList();
});

class DebugAdminPage extends ConsumerWidget {
  const DebugAdminPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final authNotifier = ref.read(authProvider.notifier);

    if (!authState.isLoggedIn || !authNotifier.isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.beamToNamed('/');
        }
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final allItemsAsync = ref.watch(allMissingItemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Admin - All Items'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(allMissingItemsProvider),
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authNotifier.logout();
              if (context.mounted) {
                context.beamToNamed('/');
              }
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: allItemsAsync.when(
        data: (items) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    'DEBUG: All Items (${items.length})',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text('Current Date: ${AppDateUtils.formatDisplayDate(DateTime.now())}'),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? const Center(
                      child: Text('No items found in storage'),
                    )
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final shopName = AppConstants.predefinedShops[item.shopId] ?? 'Unknown Shop';
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text(item.quantity.toString()),
                            ),
                            title: Text(item.itemName),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Shop: $shopName'),
                                Text('Date: ${AppDateUtils.formatDisplayDate(item.date)}'),
                                if (item.notes != null && item.notes!.isNotEmpty)
                                  Text('Notes: ${item.notes}'),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                await ref.read(missingItemNotifierProvider.notifier).deleteItem(item.id);
                                ref.refresh(allMissingItemsProvider);
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
              ElevatedButton(
                onPressed: () => ref.refresh(allMissingItemsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}