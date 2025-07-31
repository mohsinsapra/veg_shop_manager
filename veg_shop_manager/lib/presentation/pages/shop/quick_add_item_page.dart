import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beamer/beamer.dart';
import '../../providers/auth_provider.dart';
import '../../providers/missing_item_provider.dart';
import '../../../core/constants/app_constants.dart';

class BasketItem {
  final String name;
  int quantity;
  String notes;

  BasketItem({
    required this.name,
    this.quantity = 1,
    this.notes = '',
  });
}

class QuickAddItemPage extends ConsumerStatefulWidget {
  const QuickAddItemPage({super.key});

  @override
  ConsumerState<QuickAddItemPage> createState() => _QuickAddItemPageState();
}

class _QuickAddItemPageState extends ConsumerState<QuickAddItemPage> {
  final Map<String, BasketItem> _basket = {};
  final Map<String, int> _tempQuantities = {}; // Temporary quantities before adding to basket
  final _notesController = TextEditingController();
  final _searchController = TextEditingController();
  bool _isSubmitting = false;
  String _searchQuery = '';
  String _selectedCategory = 'All';

  List<String> get _categories => ['All'] + AppConstants.predefinedItems.keys.toList();

  List<String> get _filteredItems {
    List<String> items = _selectedCategory == 'All' 
        ? AppConstants.allPredefinedItems
        : AppConstants.predefinedItems[_selectedCategory] ?? [];
    
    if (_searchQuery.isNotEmpty) {
      items = items.where((item) => 
          item.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
    
    return items;
  }

  @override
  void dispose() {
    _notesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _increaseTempQuantity(String itemName) {
    setState(() {
      _tempQuantities[itemName] = (_tempQuantities[itemName] ?? 0) + 1;
    });
  }

  void _decreaseTempQuantity(String itemName) {
    setState(() {
      final currentQuantity = _tempQuantities[itemName] ?? 0;
      if (currentQuantity > 0) {
        _tempQuantities[itemName] = currentQuantity - 1;
        if (_tempQuantities[itemName] == 0) {
          _tempQuantities.remove(itemName);
          // Also remove from basket if it exists and temp quantity is 0
          if (_basket.containsKey(itemName)) {
            _basket.remove(itemName);
          }
        }
      }
    });
  }

  void _addToBasket(String itemName) {
    final quantity = _tempQuantities[itemName] ?? 0;
    if (quantity > 0) {
      setState(() {
        _basket[itemName] = BasketItem(name: itemName, quantity: quantity);
        // Reset temp quantity after adding to basket
        _tempQuantities.remove(itemName);
      });
    }
  }

  void _editBasketItem(String itemName) {
    // Move the basket quantity to temp quantity for editing
    setState(() {
      if (_basket.containsKey(itemName)) {
        _tempQuantities[itemName] = _basket[itemName]!.quantity;
        _basket.remove(itemName);
      }
    });
  }

  void _updateNotes(String itemName, String notes) {
    setState(() {
      if (_basket.containsKey(itemName)) {
        _basket[itemName]!.notes = notes;
      }
    });
  }

  void _clearBasket() {
    setState(() {
      _basket.clear();
    });
  }

  void _updateSearchQuery(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
    });
  }


  Widget _buildHighlightedText(String text, String query) {
    if (query.isEmpty) {
      return Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
        textAlign: TextAlign.center,
      );
    }

    final lowercaseText = text.toLowerCase();
    final lowercaseQuery = query.toLowerCase();
    final index = lowercaseText.indexOf(lowercaseQuery);

    if (index == -1) {
      return Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
        textAlign: TextAlign.center,
      );
    }

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
        children: [
          TextSpan(text: text.substring(0, index)),
          TextSpan(
            text: text.substring(index, index + query.length),
            style: TextStyle(
              backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.3),
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(text: text.substring(index + query.length)),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No items found',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try searching for "$_searchQuery" with different spelling\nor clear the search to see all items',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _clearSearch,
            icon: const Icon(Icons.clear),
            label: const Text('Clear Search'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitBasket() async {
    if (_basket.isEmpty) return;

    setState(() {
      _isSubmitting = true;
    });

    final authState = ref.read(authProvider);
    if (!authState.isLoggedIn || authState.currentShop == null) {
      setState(() {
        _isSubmitting = false;
      });
      return;
    }

    final missingItemNotifier = ref.read(missingItemNotifierProvider.notifier);

    try {
      // Submit all items in basket
      for (final basketItem in _basket.values) {
        await missingItemNotifier.submitItem(
          itemName: basketItem.name,
          quantity: basketItem.quantity,
          shopId: authState.currentShop!,
          notes: basketItem.notes.isEmpty ? null : basketItem.notes,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${_basket.length} items successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        context.beamToNamed('/shop');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding items: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _showBasketReview() {
    showModalBottomSheet(
      context: context,
      builder: (context) => _BasketReviewSheet(
        basket: _basket,
        onUpdateNotes: _updateNotes,
        onRemoveItem: (itemName) {
          setState(() {
            _basket.remove(itemName);
          });
          Navigator.of(context).pop();
          if (_basket.isNotEmpty) {
            _showBasketReview();
          }
        },
        onSubmit: () {
          Navigator.of(context).pop();
          _submitBasket();
        },
        onClear: () {
          Navigator.of(context).pop();
          _clearBasket();
        },
        isSubmitting: _isSubmitting,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    if (!authState.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.beamToNamed('/');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Add Items'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.beamToNamed('/shop'),
        ),
        actions: [
          // Basket icon with badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: _basket.isEmpty ? null : _showBasketReview,
              ),
              if (_basket.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${_basket.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Header info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.add_shopping_cart,
                  size: 32,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 8),
                Text(
                  'Quick Add Missing Items',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Search and add items to your basket, then review and confirm',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: _updateSearchQuery,
              decoration: InputDecoration(
                hintText: 'Search vegetables...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearSearch,
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
            ),
          ),

          // Quick search shortcuts
          if (_searchQuery.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick search:',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const SizedBox(height: 8),
                  // Category filter chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _categories.map((category) {
                        final isSelected = category == _selectedCategory;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(category, style: const TextStyle(fontSize: 12)),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _selectedCategory = category;
                                _searchController.clear();
                                _updateSearchQuery('');
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Quick search chips
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 4.0,
                    children: ['Tomate', 'Cebolla', 'Patata', 'Zanahoria', 'Pimiento']
                        .map((term) => ActionChip(
                              label: Text(term, style: const TextStyle(fontSize: 12)),
                              onPressed: () {
                                _searchController.text = term;
                                _updateSearchQuery(term);
                              },
                              backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Search results info
          if (_searchQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.filter_list,
                    size: 16,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Found ${_filteredItems.length} items for "$_searchQuery"',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _clearSearch,
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),

          // Items grid
          Expanded(
            child: _filteredItems.isEmpty
                ? _buildNoResultsState()
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.2,
                    ),
                    itemCount: _filteredItems.length,
                    itemBuilder: (context, index) {
                final item = _filteredItems[index];
                final isInBasket = _basket.containsKey(item);
                final tempQuantity = _tempQuantities[item] ?? 0;
                final basketQuantity = isInBasket ? _basket[item]!.quantity : 0;

                return Card(
                  elevation: isInBasket ? 4 : 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Item name
                        Expanded(
                          child: Center(
                            child: DefaultTextStyle(
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: isInBasket 
                                        ? Theme.of(context).primaryColor 
                                        : null,
                                  ) ?? const TextStyle(),
                              child: _buildHighlightedText(item, _searchQuery),
                            ),
                          ),
                        ),
                        
                        // Quantity controls
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              onPressed: tempQuantity > 0 ? () => _decreaseTempQuantity(item) : null,
                              icon: const Icon(Icons.remove_circle),
                              color: tempQuantity > 0 ? Colors.red : Colors.grey,
                              iconSize: 20,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8, 
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: tempQuantity > 0 
                                    ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                                    : Colors.grey.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                tempQuantity.toString(),
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: tempQuantity > 0 
                                          ? Theme.of(context).primaryColor
                                          : Colors.grey,
                                    ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => _increaseTempQuantity(item),
                              icon: const Icon(Icons.add_circle),
                              color: Theme.of(context).primaryColor,
                              iconSize: 20,
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 4),
                        
                        // Add/Edit button
                        if (isInBasket) ...[
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _editBasketItem(item),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.edit, size: 14),
                                      SizedBox(width: 4),
                                      Text('Edit', style: TextStyle(fontSize: 11)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.check, size: 14, color: Colors.green),
                                      const SizedBox(width: 4),
                                      Text(
                                        'In Cart ($basketQuantity)',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.green,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: tempQuantity > 0 ? () => _addToBasket(item) : null,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add_shopping_cart, size: 16),
                                  SizedBox(width: 4),
                                  Text('Add to Cart', style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: _basket.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _showBasketReview,
              icon: const Icon(Icons.shopping_cart),
              label: Text('Review (${_basket.length})'),
            )
          : null,
    );
  }
}

class _BasketReviewSheet extends StatefulWidget {
  final Map<String, BasketItem> basket;
  final Function(String, String) onUpdateNotes;
  final Function(String) onRemoveItem;
  final VoidCallback onSubmit;
  final VoidCallback onClear;
  final bool isSubmitting;

  const _BasketReviewSheet({
    required this.basket,
    required this.onUpdateNotes,
    required this.onRemoveItem,
    required this.onSubmit,
    required this.onClear,
    required this.isSubmitting,
  });

  @override
  State<_BasketReviewSheet> createState() => _BasketReviewSheetState();
}

class _BasketReviewSheetState extends State<_BasketReviewSheet> {
  final Map<String, TextEditingController> _notesControllers = {};

  @override
  void initState() {
    super.initState();
    for (final item in widget.basket.values) {
      _notesControllers[item.name] = TextEditingController(text: item.notes);
    }
  }

  @override
  void dispose() {
    for (final controller in _notesControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalItems = widget.basket.values.fold<int>(0, (sum, item) => sum + item.quantity);

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.shopping_cart,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Review Basket',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              Text(
                '$totalItems items',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Items list
          Expanded(
            child: ListView.builder(
              itemCount: widget.basket.length,
              itemBuilder: (context, index) {
                final item = widget.basket.values.elementAt(index);
                final controller = _notesControllers[item.name]!;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Qty: ${item.quantity}',
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => widget.onRemoveItem(item.name),
                              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                              tooltip: 'Remove from basket',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: controller,
                          decoration: const InputDecoration(
                            labelText: 'Notes (optional)',
                            hintText: 'Size, brand, special requirements...',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          maxLines: 2,
                          onChanged: (value) => widget.onUpdateNotes(item.name, value),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Actions
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.isSubmitting ? null : widget.onClear,
                  child: const Text('Clear All'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: widget.isSubmitting ? null : widget.onSubmit,
                  child: widget.isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Confirm & Add All'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}