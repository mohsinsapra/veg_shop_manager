import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beamer/beamer.dart';
import '../../providers/auth_provider.dart';
import '../../providers/missing_item_provider.dart';
import '../../providers/shopping_history_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/date_utils.dart';
import '../../../domain/entities/missing_item_entity.dart';

class AdminPage extends ConsumerWidget {
  const AdminPage({super.key});

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

    final groupedItemsAsync = ref.watch(adminMissingItemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Admin Dashboard'),
            Text(
              AppDateUtils.formatDisplayDate(AppDateUtils.today),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => context.beamToNamed('/admin/history'),
            tooltip: 'Shopping History',
          ),
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () => context.beamToNamed('/admin/debug'),
            tooltip: 'Debug View',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(adminMissingItemsProvider),
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
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor.withOpacity(0.1),
                  Theme.of(context).primaryColor.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).primaryColor.withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.admin_panel_settings,
                  size: 32,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 8),
                Text(
                  'Today\'s Shopping List',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Combined missing items from all shops',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: groupedItemsAsync.when(
              data: (groupedItems) => _buildGroupedItemsList(context, ref, groupedItems),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error loading items: $error'),
                    ElevatedButton(
                      onPressed: () => ref.refresh(adminMissingItemsProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedItemsList(
    BuildContext context,
    WidgetRef ref,
    Map<String, List<MissingItemEntity>> groupedItems,
  ) {
    if (groupedItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.celebration,
              size: 64,
              color: Colors.green[300],
            ),
            const SizedBox(height: 16),
            Text(
              'All shops are well stocked!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.green[600],
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'No missing items reported today.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      );
    }

    final sortedItems = groupedItems.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final totalItems = groupedItems.length;
    final allItems = groupedItems.values.expand((items) => items).toList();
    final totalQuantity = allItems.fold<int>(0, (sum, item) => sum + item.quantity);
    final boughtQuantity = allItems.where((item) => item.bought).fold<int>(0, (sum, item) => sum + item.quantity);
    final boughtItems = groupedItems.entries.where((entry) => entry.value.every((item) => item.bought)).length;

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    '$boughtItems/$totalItems',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: boughtItems == totalItems ? Colors.green : Theme.of(context).primaryColor,
                        ),
                  ),
                  Text(
                    'Items Bought',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              Container(
                height: 40,
                width: 1,
                color: Colors.grey[300],
              ),
              Column(
                children: [
                  Text(
                    '$boughtQuantity/$totalQuantity',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: boughtQuantity == totalQuantity ? Colors.green : Theme.of(context).primaryColor,
                        ),
                  ),
                  Text(
                    'Units Bought',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              if (boughtQuantity == totalQuantity && totalQuantity > 0) ...[
                Container(
                  height: 40,
                  width: 1,
                  color: Colors.grey[300],
                ),
                Column(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 32,
                    ),
                    Text(
                      'Complete!',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        
        // Complete Shopping List Button
        if (boughtQuantity == totalQuantity && totalQuantity > 0)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _completeShoppingList(context, ref),
              icon: const Icon(Icons.check_circle, color: Colors.white),
              label: const Text(
                'Complete Shopping List',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.refresh(adminMissingItemsProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: sortedItems.length,
              itemBuilder: (context, index) {
                final entry = sortedItems[index];
                final itemName = entry.key;
                final items = entry.value;
                return _buildGroupedItemCard(context, ref, itemName, items);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGroupedItemCard(
    BuildContext context,
    WidgetRef ref,
    String itemName,
    List<MissingItemEntity> items,
  ) {
    final totalQuantity = items.fold<int>(0, (sum, item) => sum + item.quantity);
    final boughtQuantity = items.where((item) => item.bought).fold<int>(0, (sum, item) => sum + item.quantity);
    final shopCount = items.length;
    final boughtShops = items.where((item) => item.bought).length;
    final allBought = boughtShops == shopCount;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: allBought 
                  ? Colors.green.withOpacity(0.1)
                  : Theme.of(context).primaryColor.withOpacity(0.1),
              child: Text(
                totalQuantity.toString(),
                style: TextStyle(
                  color: allBought ? Colors.green : Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (boughtQuantity > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    boughtQuantity.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          itemName,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: allBought ? TextDecoration.lineThrough : null,
            color: allBought ? Colors.grey : null,
          ),
        ),
        subtitle: Text(
          '$shopCount shop${shopCount > 1 ? 's' : ''} need this item${boughtShops > 0 ? ' • $boughtShops bought' : ''}',
          style: TextStyle(
            color: allBought ? Colors.grey : null,
          ),
        ),
        children: [
          ...items.map((item) => _buildShopItemTile(context, ref, item)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total needed: $totalQuantity units',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: allBought ? Colors.grey : Theme.of(context).primaryColor,
                      ),
                ),
                if (boughtQuantity > 0)
                  Text(
                    'Bought: $boughtQuantity units',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopItemTile(BuildContext context, WidgetRef ref, MissingItemEntity item) {
    final shopName = AppConstants.predefinedShops[item.shopId] ?? 'Unknown Shop';
    
    return ListTile(
      dense: true,
      leading: Checkbox(
        value: item.bought,
        onChanged: (bool? value) async {
          if (value != null) {
            try {
              await ref.read(missingItemNotifierProvider.notifier).toggleBoughtStatus(item.id, value);
            } catch (error) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error updating item: $error'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          }
        },
        activeColor: Colors.green,
      ),
      title: Row(
        children: [
          SizedBox(
            width: 24,
            child: Center(
              child: Text(
                item.quantity.toString(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  decoration: item.bought ? TextDecoration.lineThrough : null,
                  color: item.bought ? Colors.grey : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              shopName,
              style: TextStyle(
                decoration: item.bought ? TextDecoration.lineThrough : null,
                color: item.bought ? Colors.grey : null,
              ),
            ),
          ),
        ],
      ),
      subtitle: item.notes != null && item.notes!.isNotEmpty
          ? Text(
              item.notes!,
              style: TextStyle(
                color: item.bought ? Colors.grey[400] : Colors.grey[600],
                fontSize: 12,
                decoration: item.bought ? TextDecoration.lineThrough : null,
              ),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit, size: 18),
            onPressed: () => _editShopItem(context, ref, item),
            tooltip: 'Edit',
          ),
          IconButton(
            icon: const Icon(Icons.delete, size: 18),
            onPressed: () => _deleteShopItem(context, ref, item),
            tooltip: 'Delete',
          ),
        ],
      ),
    );
  }

  void _editShopItem(BuildContext context, WidgetRef ref, MissingItemEntity item) {
    _showEditDialog(context, ref, item);
  }

  void _deleteShopItem(BuildContext context, WidgetRef ref, MissingItemEntity item) {
    final shopName = AppConstants.predefinedShops[item.shopId] ?? 'Unknown Shop';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text(
            'Are you sure you want to delete "${item.itemName}" from $shopName?'),
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

  void _showEditDialog(BuildContext context, WidgetRef ref, MissingItemEntity item) {
    final itemNameController = TextEditingController(text: item.itemName);
    final quantityController = TextEditingController(text: item.quantity.toString());
    final notesController = TextEditingController(text: item.notes ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Item'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: itemNameController,
                decoration: const InputDecoration(labelText: 'Item Name'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter item name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: quantityController,
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter quantity';
                  }
                  final quantity = int.tryParse(value);
                  if (quantity == null || quantity <= 0) {
                    return 'Please enter a valid positive number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Notes (Optional)'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop();
                await ref.read(missingItemNotifierProvider.notifier).submitItem(
                      itemName: itemNameController.text.trim(),
                      quantity: int.parse(quantityController.text),
                      shopId: item.shopId,
                      notes: notesController.text.trim().isEmpty 
                          ? null 
                          : notesController.text.trim(),
                      id: item.id,
                      bought: item.bought,
                    );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _completeShoppingList(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Shopping List'),
        content: const Text(
          'Are you sure you want to complete this shopping list? This will move all items to history and clear the current list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await ref.read(shoppingHistoryNotifierProvider.notifier).completeShoppingList();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Shopping list completed and moved to history!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error completing list: $error'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Complete'),
          ),
        ],
      ),
    );
  }
}