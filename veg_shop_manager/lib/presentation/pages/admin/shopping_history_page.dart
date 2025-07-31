import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beamer/beamer.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shopping_history_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/date_utils.dart';
import '../../../domain/entities/shopping_history_entity.dart';

class ShoppingHistoryPage extends ConsumerWidget {
  const ShoppingHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final authNotifier = ref.read(authProvider.notifier);

    if (!authState.isLoggedIn || !authNotifier.isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.beamToNamed('/');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final historyAsync = ref.watch(shoppingHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(shoppingHistoryProvider),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: historyAsync.when(
        data: (history) => _buildHistoryList(context, ref, history),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading history: $error'),
              ElevatedButton(
                onPressed: () => ref.refresh(shoppingHistoryProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryList(
    BuildContext context,
    WidgetRef ref,
    List<ShoppingHistoryEntity> history,
  ) {
    if (history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Shopping History',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete shopping lists will appear here.',
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
        ref.refresh(shoppingHistoryProvider);
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: history.length,
        itemBuilder: (context, index) {
          final historyItem = history[index];
          return _buildHistoryCard(context, ref, historyItem);
        },
      ),
    );
  }

  Widget _buildHistoryCard(
    BuildContext context,
    WidgetRef ref,
    ShoppingHistoryEntity history,
  ) {
    final daysSince = DateTime.now().difference(history.completedDate).inDays;
    String timeAgo;
    if (daysSince == 0) {
      timeAgo = 'Today';
    } else if (daysSince == 1) {
      timeAgo = 'Yesterday';
    } else {
      timeAgo = '$daysSince days ago';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.withOpacity(0.1),
          child: Icon(
            Icons.check_circle,
            color: Colors.green,
          ),
        ),
        title: Text(
          'Shopping List - ${AppDateUtils.formatDisplayDate(history.originalDate)}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Completed $timeAgo'),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.shopping_cart, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${history.totalItems} items • ${history.totalQuantity} units',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
          onPressed: () => _deleteHistory(context, ref, history),
          tooltip: 'Delete',
        ),
        children: [
          _buildHistoryItems(context, history),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Completed: ${AppDateUtils.formatDateTime(history.completedDate)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItems(BuildContext context, ShoppingHistoryEntity history) {
    // Group items by name
    final Map<String, List<dynamic>> groupedItems = {};
    for (final item in history.items) {
      if (groupedItems[item.itemName] == null) {
        groupedItems[item.itemName] = [];
      }
      groupedItems[item.itemName]!.add({
        'quantity': item.quantity,
        'shopId': item.shopId,
        'notes': item.notes,
        'bought': item.bought,
      });
    }

    return Column(
      children: groupedItems.entries.map((entry) {
        final itemName = entry.key;
        final items = entry.value;
        final totalQuantity = items.fold<int>(0, (sum, item) => sum + (item['quantity'] as int));
        
        return ListTile(
          dense: true,
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: Colors.green.withOpacity(0.1),
            child: Text(
              totalQuantity.toString(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ),
          title: Text(
            itemName,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.lineThrough,
              color: Colors.grey,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items.map<Widget>((item) {
              final shopName = AppConstants.predefinedShops[item['shopId']] ?? 'Unknown Shop';
              return Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${item['quantity']} units - $shopName${item['notes'] != null && item['notes'].isNotEmpty ? ' (${item['notes']})' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              );
            }).toList(),
          ),
          trailing: const Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 20,
          ),
        );
      }).toList(),
    );
  }

  void _deleteHistory(BuildContext context, WidgetRef ref, ShoppingHistoryEntity history) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete History'),
        content: Text(
          'Are you sure you want to delete the shopping list from ${AppDateUtils.formatDisplayDate(history.originalDate)}?',
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
                await ref.read(shoppingHistoryNotifierProvider.notifier).deleteHistory(history.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('History deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting history: $error'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}