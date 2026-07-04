import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beamer/beamer.dart';
import '../../providers/auth_provider.dart';
import '../../providers/missing_item_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/l10n/l10n_extension.dart';

class StepByStepAddPage extends ConsumerStatefulWidget {
  const StepByStepAddPage({super.key});

  @override
  ConsumerState<StepByStepAddPage> createState() => _StepByStepAddPageState();
}

class _StepByStepAddPageState extends ConsumerState<StepByStepAddPage>
    with TickerProviderStateMixin {
  final _quantityController = TextEditingController();
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  List<String> _filteredItems = [];
  List<String> _allItems = [];
  int _currentIndex = 0;
  String _searchQuery = '';
  final Map<String, int> _quantities = {};
  bool _isSubmitting = false;

  // Animation and drag state
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  double _dragOffset = 0.0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _allItems = AppConstants.allPredefinedItems;
    _filteredItems = List.from(_allItems);
    _searchController.addListener(_onSearchChanged);

    // Initialize animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Keep numpad open by focusing after frame and load initial quantity
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadQuantityForCurrentItem();
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    // Save current quantity before disposing
    _saveCurrentQuantity();
    _animationController.dispose();
    _quantityController.dispose();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    // Save current quantity before changing search
    _saveCurrentQuantity();

    if (mounted) {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
        _filteredItems = _allItems
            .where((item) => item.toLowerCase().contains(_searchQuery))
            .toList();

        // Reset to first item when search changes
        if (_filteredItems.isNotEmpty) {
          _currentIndex = 0;
        } else {
          _currentIndex = 0; // Reset index even if no items found
        }
      });
      // Load quantity for new current item
      _loadQuantityForCurrentItem();
    }
  }

  void _nextItem() {
    if (_filteredItems.isNotEmpty) {
      // Add haptic feedback
      HapticFeedback.lightImpact();
      
      // Save current quantity before moving
      _saveCurrentQuantity();
      
      // Animate to next item
      _animateAndNavigate(false, () {
        if (mounted) {
          setState(() {
            _currentIndex = (_currentIndex + 1) % _filteredItems.length;
          });
          _loadQuantityForCurrentItem();
          _keepFocus();
        }
      });
    }
  }

  void _previousItem() {
    if (_filteredItems.isNotEmpty) {
      // Add haptic feedback
      HapticFeedback.lightImpact();
      
      // Save current quantity before moving
      _saveCurrentQuantity();
      
      // Animate to previous item
      _animateAndNavigate(true, () {
        if (mounted) {
          setState(() {
            _currentIndex =
                (_currentIndex - 1 + _filteredItems.length) %
                _filteredItems.length;
          });
          _loadQuantityForCurrentItem();
          _keepFocus();
        }
      });
    }
  }

  void _loadQuantityForCurrentItem() {
    if (_filteredItems.isNotEmpty &&
        _currentIndex >= 0 &&
        _currentIndex < _filteredItems.length) {
      final currentItem = _filteredItems[_currentIndex];
      final quantity = _quantities[currentItem] ?? 0;
      _quantityController.text = quantity > 0 ? quantity.toString() : '';
    } else {
      // Clear the text field if no valid item
      _quantityController.text = '';
    }
  }

  void _saveCurrentQuantity() {
    if (_filteredItems.isNotEmpty &&
        _currentIndex >= 0 &&
        _currentIndex < _filteredItems.length) {
      final currentItem = _filteredItems[_currentIndex];
      final quantity = int.tryParse(_quantityController.text) ?? 0;
      if (quantity > 0) {
        _quantities[currentItem] = quantity;
      } else {
        _quantities.remove(currentItem);
      }
    }
  }

  void _keepFocus() {
    // Keep the focus on the text field to maintain numpad
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  void _onDragStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
    });
    _animationController.stop();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta.dx;
      // Limit drag distance to screen width
      _dragOffset = _dragOffset.clamp(-400.0, 400.0);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
    });

    const double threshold =
        100.0; // Minimum drag distance to trigger navigation

    if (_dragOffset > threshold) {
      // Dragged right - go to previous item
      _animateAndNavigate(true, () => _previousItem());
    } else if (_dragOffset < -threshold) {
      // Dragged left - go to next item
      _animateAndNavigate(false, () => _nextItem());
    } else {
      // Snap back to center
      _animateToCenter();
    }
  }

  void _animateAndNavigate(bool isRight, VoidCallback navigationCallback) {
    final double targetOffset = isRight ? 400.0 : -400.0;

    _slideAnimation = Tween<double>(begin: _dragOffset, end: targetOffset)
        .animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOut,
          ),
        );

    _animationController.forward().then((_) {
      // Navigate to new item
      navigationCallback();

      // Reset position and animate in from opposite side smoothly
      _dragOffset = isRight ? -400.0 : 400.0;
      _slideAnimation = Tween<double>(begin: _dragOffset, end: 0.0).animate(
        CurvedAnimation(
          parent: _animationController, 
          curve: Curves.easeInOut,
        ),
      );

      _animationController.reset();
      _animationController.forward().then((_) {
        setState(() {
          _dragOffset = 0.0;
        });
      });
    });
  }

  void _animateToCenter() {
    _slideAnimation = Tween<double>(begin: _dragOffset, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.reset();
    _animationController.forward().then((_) {
      setState(() {
        _dragOffset = 0.0;
      });
    });
  }

  Future<void> _submitItems() async {
    if (_quantities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.stepAddNoQuantityWarning),
        ),
      );
      return;
    }

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

    try {
      final notifier = ref.read(missingItemNotifierProvider.notifier);

      for (final entry in _quantities.entries) {
        await notifier.submitItem(
          itemName: entry.key,
          quantity: entry.value,
          shopId: authState.currentShop!,
          notes: null,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.stepAddAddedSuccess(_quantities.length)),
          ),
        );
        context.beamToNamed('/shop');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.stepAddErrorGeneric(e.toString()))));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showScreenSelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.stepAddChooseMethodTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.add),
              title: Text(context.l10n.addSingleItemLabel),
              onTap: () {
                Navigator.pop(context);
                context.beamToNamed('/shop/add');
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_shopping_cart),
              title: Text(context.l10n.quickAddMultipleLabel),
              onTap: () {
                Navigator.pop(context);
                context.beamToNamed('/shop/quick-add');
              },
            ),
            ListTile(
              leading: const Icon(Icons.navigate_next),
              title: Text(context.l10n.stepByStepAddLabel),
              trailing: const Icon(Icons.check, color: Colors.green),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

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
        title: Text(context.l10n.stepByStepAddLabel),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.beamToNamed('/shop'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            onPressed: _showScreenSelector,
            tooltip: context.l10n.stepAddSwitchMethodTooltip,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: context.l10n.stepAddSearchLabel,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _saveCurrentQuantity();
                          _searchController.clear();
                          _keepFocus();
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
            ),
          ),

          // Current Item Display
          if (_filteredItems.isNotEmpty) ...[
            Expanded(
              child: Column(
                children: [
                  // Progress indicator
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.l10n.stepAddItemProgress(_currentIndex + 1, _filteredItems.length),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            context.l10n.stepAddAddedCount(_quantities.length),
                            style: TextStyle(
                              color: Colors.green[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Draggable Card with Background Indicators
                  Expanded(
                    child: Stack(
                      children: [
                        if (_isDragging) ...[
                          // Left indicator (Previous)
                          Positioned(
                            left: 20,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: AnimatedOpacity(
                                opacity: _dragOffset > 50 ? 1.0 : 0.3,
                                duration: const Duration(milliseconds: 100),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[600],
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: const Icon(
                                    Icons.arrow_back,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Right indicator (Next)
                          Positioned(
                            right: 20,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: AnimatedOpacity(
                                opacity: _dragOffset < -50 ? 1.0 : 0.3,
                                duration: const Duration(milliseconds: 100),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.green[600],
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: const Icon(
                                    Icons.arrow_forward,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],

                        // Main draggable card
                        AnimatedBuilder(
                          animation: _slideAnimation,
                          builder: (context, child) {
                            final double currentOffset = _isDragging
                                ? _dragOffset
                                : _slideAnimation.value;
                            final double opacity =
                                1.0 -
                                (_dragOffset.abs() / 400.0).clamp(0.0, 0.3);
                            final double scale =
                                1.0 -
                                (_dragOffset.abs() / 800.0).clamp(0.0, 0.1);

                            return Transform.translate(
                              offset: Offset(currentOffset, 0),
                              child: Transform.scale(
                                scale: scale,
                                child: Opacity(
                                  opacity: opacity,
                                  child: GestureDetector(
                                    onHorizontalDragStart: _onDragStart,
                                    onHorizontalDragUpdate: _onDragUpdate,
                                    onHorizontalDragEnd: _onDragEnd,
                                    child: Container(
                                      margin: const EdgeInsets.all(16),
                                      child: Card(
                                        elevation: 8,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(32),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                Colors.white,
                                                Colors.grey[50]!,
                                              ],
                                            ),
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Container(
                                                width: 120,
                                                height: 120,
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context)
                                                      .primaryColor
                                                      .withValues(alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  border: Border.all(
                                                    color: Theme.of(context)
                                                        .primaryColor
                                                        .withValues(alpha: 0.3),
                                                    width: 2,
                                                  ),
                                                ),
                                                child: Icon(
                                                  Icons.inventory_2,
                                                  size: 60,
                                                  color: Theme.of(
                                                    context,
                                                  ).primaryColor,
                                                ),
                                              ),
                                              const SizedBox(height: 32),

                                              // Item Name
                                              Text(
                                                _filteredItems[_currentIndex],
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .headlineMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.grey[800],
                                                    ),
                                                textAlign: TextAlign.center,
                                              ),
                                              const SizedBox(height: 40),

                                              // Quantity Input
                                              SizedBox(
                                                width: 200,
                                                child: TextField(
                                                  controller:
                                                      _quantityController,
                                                  focusNode: _focusNode,
                                                  keyboardType:
                                                      TextInputType.number,
                                                  inputFormatters: [
                                                    FilteringTextInputFormatter
                                                        .digitsOnly,
                                                  ],
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                    fontSize: 32,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  decoration: InputDecoration(
                                                    labelText: context.l10n.stepAddQuantityLabel,
                                                    labelStyle: TextStyle(
                                                      fontSize: 16,
                                                      color: Colors.grey[600],
                                                    ),
                                                    border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                      borderSide: BorderSide(
                                                        color: Theme.of(
                                                          context,
                                                        ).primaryColor,
                                                        width: 2,
                                                      ),
                                                    ),
                                                    focusedBorder:
                                                        OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                12,
                                                              ),
                                                          borderSide:
                                                              BorderSide(
                                                                color: Theme.of(
                                                                  context,
                                                                ).primaryColor,
                                                                width: 3,
                                                              ),
                                                        ),
                                                    contentPadding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 20,
                                                          horizontal: 16,
                                                        ),
                                                  ),
                                                  onChanged: (value) {
                                                    if (mounted) {
                                                      _saveCurrentQuantity();
                                                    }
                                                  },
                                                  onSubmitted: (value) {
                                                    _saveCurrentQuantity();
                                                    _nextItem();
                                                  },
                                                ),
                                              ),
                                              const SizedBox(height: 24),

                                              // Drag hint
                                              _isDragging
                                                  ? Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        if (_dragOffset >
                                                            50) ...[
                                                          Icon(
                                                            Icons.arrow_back,
                                                            color: Colors
                                                                .blue[600],
                                                          ),
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          Text(
                                                            context.l10n
                                                                .stepAddReleaseBack,
                                                            style: TextStyle(
                                                              color: Colors
                                                                  .blue[600],
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                          ),
                                                        ] else if (_dragOffset <
                                                            -50) ...[
                                                          Text(
                                                            context.l10n
                                                                .stepAddReleaseForward,
                                                            style: TextStyle(
                                                              color: Colors
                                                                  .green[600],
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          Icon(
                                                            Icons.arrow_forward,
                                                            color: Colors
                                                                .green[600],
                                                          ),
                                                        ] else ...[
                                                          Text(
                                                            context.l10n
                                                                .stepAddKeepDragging,
                                                            style: TextStyle(
                                                              color: Colors
                                                                  .grey[600],
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                          ),
                                                        ],
                                                      ],
                                                    )
                                                  : Text(
                                                      context.l10n
                                                          .stepAddDragHint,
                                                      style: TextStyle(
                                                        color: Colors.grey[500],
                                                        fontSize: 14,
                                                        fontStyle:
                                                            FontStyle.italic,
                                                      ),
                                                    ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Expanded(
              child: Center(
                child: Text(
                  context.l10n.stepAddNoItemsFound,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ],
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Previous Button
          FloatingActionButton(
            heroTag: "previous",
            onPressed: _filteredItems.isNotEmpty ? _previousItem : null,
            backgroundColor: _filteredItems.isNotEmpty
                ? Theme.of(context).primaryColor
                : Colors.grey,
            child: const Icon(Icons.navigate_before),
          ),

          // Submit Button
          FloatingActionButton.extended(
            heroTag: "submit",
            onPressed: _isSubmitting ? null : _submitItems,
            backgroundColor: _quantities.isNotEmpty
                ? Colors.green
                : Colors.grey,
            label: _isSubmitting
                ? Text(context.l10n.stepAddSubmitting)
                : Text(context.l10n.stepAddSubmitCount(_quantities.length)),
            icon: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
          ),

          // Next Button
          FloatingActionButton(
            heroTag: "next",
            onPressed: _filteredItems.isNotEmpty ? _nextItem : null,
            backgroundColor: _filteredItems.isNotEmpty
                ? Theme.of(context).primaryColor
                : Colors.grey,
            child: const Icon(Icons.navigate_next),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
