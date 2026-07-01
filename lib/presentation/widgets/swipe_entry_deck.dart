import 'package:flutter/material.dart';
import '../../domain/entities/catalog_item_entity.dart';
import 'entry_item_controls.dart';

/// Tinder-style card deck: one item at a time. Swipe right (or tap Add) to put
/// it on the list, swipe left (or tap Skip) to move on. The − / + stepper sets
/// an exact quantity before you move on.
class SwipeEntryDeck extends StatefulWidget {
  final List<CatalogItemEntity> items;
  final Map<String, int> qtyByItem;
  final Future<void> Function(CatalogItemEntity item, int qty) onSet;
  const SwipeEntryDeck({
    super.key,
    required this.items,
    required this.qtyByItem,
    required this.onSet,
  });

  @override
  State<SwipeEntryDeck> createState() => _SwipeEntryDeckState();
}

class _SwipeEntryDeckState extends State<SwipeEntryDeck> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    if (items.isEmpty) {
      return const Center(child: Text('No items.'));
    }
    if (_i >= items.length) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green[600]),
            const SizedBox(height: 12),
            const Text('All items reviewed.'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.replay),
              label: const Text('Start over'),
              onPressed: () => setState(() => _i = 0),
            ),
          ],
        ),
      );
    }

    final item = items[_i];
    final qty = widget.qtyByItem[item.id] ?? 0;

    void next() => setState(() => _i++);
    void prev() => setState(() => _i = _i > 0 ? _i - 1 : 0);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: (_i + 1) / items.length,
                  minHeight: 6,
                ),
              ),
              const SizedBox(width: 12),
              Text('${_i + 1} / ${items.length}'),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Dismissible(
                key: ValueKey('${item.id}_$_i'),
                onDismissed: (dir) {
                  if (dir == DismissDirection.startToEnd && qty == 0) {
                    widget.onSet(item, 1);
                  }
                  next();
                },
                background: _swipeBg(Colors.green, Icons.add, 'Add',
                    Alignment.centerLeft),
                secondaryBackground: _swipeBg(Colors.blueGrey,
                    Icons.skip_next, 'Skip', Alignment.centerRight),
                child: _card(context, item, qty),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton.filledTonal(
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Previous',
                onPressed: _i > 0 ? prev : null,
              ),
              FilledButton.icon(
                icon: const Icon(Icons.skip_next),
                label: const Text('Skip'),
                style: FilledButton.styleFrom(backgroundColor: Colors.blueGrey),
                onPressed: next,
              ),
              FilledButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('Next'),
                onPressed: () {
                  if (qty == 0) widget.onSet(item, 1);
                  next();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _card(BuildContext context, CatalogItemEntity item, int qty) {
    final active = qty > 0;
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: active
            ? const BorderSide(color: Colors.green, width: 2)
            : BorderSide(color: Colors.grey.shade300),
      ),
      child: Container(
        width: 320,
        height: 320,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Text('${_i + 1}',
                  style: TextStyle(color: Colors.grey[400])),
            ),
            Expanded(
              child: Center(
                child: Text(
                  item.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            EntryQtyStepper(
              qty: qty,
              onDecrement: qty > 0 ? () => widget.onSet(item, qty - 1) : null,
              onIncrement: () => widget.onSet(item, qty + 1),
            ),
            const SizedBox(height: 4),
            Text('Swipe →  add    ←  skip',
                style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _swipeBg(Color color, IconData icon, String label, Alignment align) {
    return Container(
      alignment: align,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 40),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
