import 'package:flutter/material.dart';

/// A compact quantity stepper: − [qty] + . Used in both list and grid entry views.
class EntryQtyStepper extends StatelessWidget {
  final int qty;
  final VoidCallback? onDecrement; // null disables (qty already 0)
  final VoidCallback onIncrement;
  const EntryQtyStepper({
    super.key,
    required this.qty,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: onDecrement,
          visualDensity: VisualDensity.compact,
        ),
        SizedBox(
          width: 36,
          child: Text('$qty',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: qty > 0 ? Colors.green[800] : Colors.grey)),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: onIncrement,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

/// A card tile for the grid view: item name with a stepper, highlighted when
/// a quantity is set.
class EntryCard extends StatelessWidget {
  final String name;
  final int qty;
  final VoidCallback? onDecrement;
  final VoidCallback onIncrement;
  const EntryCard({
    super.key,
    required this.name,
    required this.qty,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    final active = qty > 0;
    return Card(
      margin: const EdgeInsets.all(4),
      color: active ? Colors.green.withValues(alpha: 0.08) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: active
            ? const BorderSide(color: Colors.green, width: 1.4)
            : BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            EntryQtyStepper(
              qty: qty,
              onDecrement: onDecrement,
              onIncrement: onIncrement,
            ),
          ],
        ),
      ),
    );
  }
}
