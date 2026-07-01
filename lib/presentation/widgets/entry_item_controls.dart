import 'package:flutter/material.dart';

/// How the entry catalog is presented.
enum EntryViewMode { list, grid, swipe }

/// A view-mode picker (list / grid / swipe) for the app bar.
class EntryViewMenu extends StatelessWidget {
  final EntryViewMode mode;
  final ValueChanged<EntryViewMode> onChanged;
  const EntryViewMenu({super.key, required this.mode, required this.onChanged});

  IconData _icon(EntryViewMode m) => switch (m) {
        EntryViewMode.list => Icons.view_list,
        EntryViewMode.grid => Icons.grid_view,
        EntryViewMode.swipe => Icons.style,
      };

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<EntryViewMode>(
      icon: Icon(_icon(mode)),
      tooltip: 'View',
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final m in EntryViewMode.values)
          PopupMenuItem(
            value: m,
            child: Row(children: [
              Icon(_icon(m),
                  size: 20,
                  color: m == mode ? Theme.of(context).colorScheme.primary : null),
              const SizedBox(width: 12),
              Text(switch (m) {
                EntryViewMode.list => 'List',
                EntryViewMode.grid => 'Grid',
                EntryViewMode.swipe => 'Swipe',
              }),
            ]),
          ),
      ],
    );
  }
}

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
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      color: active ? const Color(0xFFEAF7EC) : Colors.white,
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
