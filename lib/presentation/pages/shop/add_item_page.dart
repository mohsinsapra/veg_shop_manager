import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beamer/beamer.dart';
import '../../providers/auth_provider.dart';
import '../../providers/missing_item_provider.dart';
import '../../../domain/entities/missing_item_entity.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/l10n/l10n_extension.dart';

/// Translates the fixed category keys from [AppConstants.predefinedItems]
/// (and the synthetic "All" filter) into localized labels. Individual item
/// names inside each category are catalog data and stay untranslated.
String categoryLabel(BuildContext context, String key) {
  switch (key) {
    case 'All':
      return context.l10n.categoryAll;
    case 'Vegetables':
      return context.l10n.categoryVegetables;
    case 'Tomatoes':
      return context.l10n.categoryTomatoes;
    case 'Peppers':
      return context.l10n.categoryPeppers;
    case 'Stone Fruits':
      return context.l10n.categoryStoneFruits;
    case 'Citrus':
      return context.l10n.categoryCitrus;
    case 'Other Fruits':
      return context.l10n.categoryOtherFruits;
    case 'Accessories':
      return context.l10n.categoryAccessories;
    default:
      return key;
  }
}

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
          content: Text(context.l10n.addItemErrorGeneric(state.error.toString())),
          backgroundColor: Colors.red,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing
              ? context.l10n.addItemUpdatedSuccess
              : context.l10n.addItemAddedSuccess),
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
        title: Text(_isEditing ? context.l10n.addItemEditTitle : context.l10n.addItemAddTitle),
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
                            _isEditing ? context.l10n.addItemUpdateHeading : context.l10n.addItemAddTitle,
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
                          labelText: context.l10n.addItemNameLabel,
                          hintText: context.l10n.addItemNameHint,
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
                            return context.l10n.addItemNameRequired;
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
                                  decoration: InputDecoration(
                                    hintText: context.l10n.addItemSearchHint,
                                    prefixIcon: const Icon(Icons.search),
                                    border: const OutlineInputBorder(),
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
                                        label: Text(categoryLabel(context, category), style: TextStyle(fontSize: 12)),
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
                        decoration: InputDecoration(
                          labelText: context.l10n.addItemQuantityLabel,
                          hintText: context.l10n.addItemQuantityHint,
                          prefixIcon: const Icon(Icons.numbers),
                          suffixText: context.l10n.addItemUnitsSuffix,
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return context.l10n.addItemQuantityRequired;
                          }
                          final quantity = int.tryParse(value);
                          if (quantity == null || quantity <= 0) {
                            return context.l10n.addItemQuantityInvalid;
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _notesController,
                        decoration: InputDecoration(
                          labelText: context.l10n.addItemNotesLabel,
                          hintText: context.l10n.addItemNotesHint,
                          prefixIcon: const Icon(Icons.note),
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
                        _isEditing ? context.l10n.addItemUpdateButton : context.l10n.addItemAddButton,
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
                            context.l10n.addItemQuickTipsHeading,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.addItemQuickTipsBody,
                        style: const TextStyle(fontSize: 14),
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