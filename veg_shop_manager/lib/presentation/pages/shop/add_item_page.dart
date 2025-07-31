import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beamer/beamer.dart';
import '../../providers/auth_provider.dart';
import '../../providers/missing_item_provider.dart';
import '../../../domain/entities/missing_item_entity.dart';
import '../../../core/constants/app_constants.dart';

class AddItemPage extends ConsumerStatefulWidget {
  const AddItemPage({super.key});

  @override
  ConsumerState<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends ConsumerState<AddItemPage> {
  final _formKey = GlobalKey<FormState>();
  final _itemNameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _notesController = TextEditingController();
  final _searchController = TextEditingController();
  
  MissingItemEntity? _editingItem;
  String _selectedCategory = 'All';
  List<String> _filteredItems = [];
  bool _showItemList = false;

  List<String> get _categories => ['All'] + AppConstants.predefinedItems.keys.toList();

  void _filterItems() {
    setState(() {
      List<String> items = _selectedCategory == 'All' 
          ? AppConstants.allPredefinedItems
          : AppConstants.predefinedItems[_selectedCategory] ?? [];
      
      if (_searchController.text.isNotEmpty) {
        items = items.where((item) => 
            item.toLowerCase().contains(_searchController.text.toLowerCase())
        ).toList();
      }
      
      _filteredItems = items;
    });
  }

  @override
  void initState() {
    super.initState();
    _filteredItems = AppConstants.allPredefinedItems;
    _searchController.addListener(_filterItems);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final data = context.currentBeamLocation.data as MissingItemEntity?;
        if (data != null) {
          setState(() {
            _editingItem = data;
            _itemNameController.text = data.itemName;
            _quantityController.text = data.quantity.toString();
            _notesController.text = data.notes ?? '';
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _quantityController.dispose();
    _notesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool get _isEditing => _editingItem != null;

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final authState = ref.read(authProvider);
    if (!authState.isLoggedIn || authState.currentShop == null) return;

    final missingItemNotifier = ref.read(missingItemNotifierProvider.notifier);
    
    await missingItemNotifier.submitItem(
      itemName: _itemNameController.text.trim(),
      quantity: int.parse(_quantityController.text),
      shopId: authState.currentShop!,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      id: _editingItem?.id,
    );

    final state = ref.read(missingItemNotifierProvider);
    if (state.hasError && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${state.error}'),
          backgroundColor: Colors.red,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Item updated successfully!' : 'Item added successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      context.beamToNamed('/shop');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final missingItemState = ref.watch(missingItemNotifierProvider);

    if (!authState.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.beamToNamed('/');
        }
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Item' : 'Add Missing Item'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.beamToNamed('/shop'),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isEditing ? Icons.edit : Icons.add_shopping_cart,
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isEditing ? 'Update Missing Item' : 'Add Missing Item',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _itemNameController,
                        decoration: InputDecoration(
                          labelText: 'Item Name *',
                          hintText: 'Type or select from list below',
                          prefixIcon: const Icon(Icons.shopping_basket),
                          suffixIcon: IconButton(
                            icon: Icon(_showItemList ? Icons.expand_less : Icons.expand_more),
                            onPressed: () {
                              setState(() {
                                _showItemList = !_showItemList;
                              });
                            },
                          ),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter item name';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Show item selection interface
                      if (_showItemList) ...[
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              // Search bar
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: TextField(
                                  controller: _searchController,
                                  decoration: const InputDecoration(
                                    hintText: 'Search items...',
                                    prefixIcon: Icon(Icons.search),
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              
                              // Category tabs
                              Container(
                                height: 40,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _categories.length,
                                  itemBuilder: (context, index) {
                                    final category = _categories[index];
                                    final isSelected = category == _selectedCategory;
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: ChoiceChip(
                                        label: Text(category, style: TextStyle(fontSize: 12)),
                                        selected: isSelected,
                                        onSelected: (selected) {
                                          setState(() {
                                            _selectedCategory = category;
                                            _filterItems();
                                          });
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ),
                              
                              // Items list
                              Container(
                                height: 200,
                                child: ListView.builder(
                                  itemCount: _filteredItems.length,
                                  itemBuilder: (context, index) {
                                    final item = _filteredItems[index];
                                    return ListTile(
                                      dense: true,
                                      title: Text(item),
                                      onTap: () {
                                        setState(() {
                                          _itemNameController.text = item;
                                          _showItemList = false;
                                        });
                                      },
                                      trailing: _itemNameController.text == item 
                                          ? const Icon(Icons.check, color: Colors.green)
                                          : null,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _quantityController,
                        decoration: const InputDecoration(
                          labelText: 'Quantity *',
                          hintText: 'e.g., 5, 10',
                          prefixIcon: Icon(Icons.numbers),
                          suffixText: 'units/kg',
                        ),
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
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Notes (Optional)',
                          hintText: 'e.g., Large size, Fresh, Brand preference',
                          prefixIcon: Icon(Icons.note),
                        ),
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              ElevatedButton(
                onPressed: missingItemState.isLoading ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: missingItemState.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _isEditing ? 'Update Item' : 'Add Item',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
              
              const SizedBox(height: 16),
              
              Card(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            size: 20,
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Quick Tips',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• Tap the chip buttons for quick vegetable selection\n'
                        '• Quantity can be in units, kg, or any measure you prefer\n'
                        '• Add notes for specific requirements like size or brand\n'
                        '• You can edit or delete items from the main screen',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}