import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beamer/beamer.dart';
import '../../providers/auth_provider.dart';
import '../../providers/missing_item_provider.dart';
import '../../../core/utils/date_utils.dart';
import '../../../domain/entities/missing_item_entity.dart';

class ShopHomePage extends ConsumerWidget {
  const ShopHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final authNotifier = ref.read(authProvider.notifier);

    if (!authState.isLoggedIn || !authNotifier.isShopUser) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.beamToNamed('/');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final shopId = authState.currentShop!;
    final shopName = authNotifier.currentShopName;
    final missingItemsAsync = ref.watch(shopMissingItemsProvider(shopId));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(shopName),
            Text(
              AppDateUtils.formatDisplayDate(AppDateUtils.today),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
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
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).primaryColor.withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.inventory_2,
                  size: 32,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 8),
                Text(
                  'Today\'s Missing Items',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Track what you need to stock up on',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: missingItemsAsync.when(
              data: (items) => _buildItemsList(context, ref, items, shopId),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error loading items: $error'),
                    ElevatedButton(
                      onPressed: () => ref.refresh(shopMissingItemsProvider(shopId)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.beamToNamed('/shop/add'),
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
      ),
    );
  }

  Widget _buildItemsList(BuildContext context, WidgetRef ref, List<MissingItemEntity> items, String shopId) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.green[300],
            ),
            const SizedBox(height: 16),
            Text(
              'All stocked up!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.green[600],
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'No missing items for today.\nTap the + button to add items.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.refresh(shopMissingItemsProvider(shopId));
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return _buildItemCard(context, ref, item);
        },
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, WidgetRef ref, MissingItemEntity item) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
          child: Text(
            item.quantity.toString(),
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          item.itemName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: item.notes != null && item.notes!.isNotEmpty
            ? Text(item.notes!)
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () => _editItem(context, item),
              tooltip: 'Edit',
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20),
              onPressed: () => _deleteItem(context, ref, item),
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }

  void _editItem(BuildContext context, MissingItemEntity item) {
    context.beamToNamed('/shop/add', data: item);
  }

  void _deleteItem(BuildContext context, WidgetRef ref, MissingItemEntity item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete "${item.itemName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await ref.read(missingItemNotifierProvider.notifier).deleteItem(item.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}