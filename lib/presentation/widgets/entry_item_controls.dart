import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/l10n/l10n_extension.dart';
import '../../core/utils/qty_format.dart';

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
      tooltip: context.l10n.entryControlsView,
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
                EntryViewMode.list => context.l10n.entryControlsList,
                EntryViewMode.grid => context.l10n.entryControlsGrid,
                EntryViewMode.swipe => context.l10n.entryControlsSwipe,
              }),
            ]),
          ),
      ],
    );
  }
}

/// Parses a user-typed quantity: normalizes ',' to '.', clamps negatives/NaN
/// to 0, and rounds to the nearest 0.5 step.
double parseQty(String raw) {
  final normalized = raw.trim().replaceAll(',', '.');
  final v = double.tryParse(normalized);
  if (v == null || v < 0) return 0;
  return (v * 2).round() / 2;
}

/// A compact quantity stepper: − [qty] + . Used in both list and grid entry
/// views. The middle control is a type-in field so members can enter a value
/// directly; pressing "next" (or losing focus) commits it and — when a
/// [focusNode] is supplied by the caller — hands focus to the next item.
class EntryQtyStepper extends StatefulWidget {
  final double qty;
  final VoidCallback? onDecrement; // null disables (qty already 0)
  final VoidCallback onIncrement;
  final ValueChanged<double>? onQtyEntered;
  final VoidCallback? onNext; // fired only on the keyboard "next" action
  final FocusNode? focusNode;
  final bool big; // larger, boxed field (swipe cards)
  const EntryQtyStepper({
    super.key,
    required this.qty,
    required this.onDecrement,
    required this.onIncrement,
    this.onQtyEntered,
    this.onNext,
    this.focusNode,
    this.big = false,
  });

  @override
  State<EntryQtyStepper> createState() => _EntryQtyStepperState();
}

class _EntryQtyStepperState extends State<EntryQtyStepper> {
  late final TextEditingController _controller;
  double? _lastSent;

  String _textFor(double qty) => qty == 0 ? '' : fmtQty(qty);

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _textFor(widget.qty));
    widget.focusNode?.addListener(_onFocusGained);
  }

  // Select the whole value on focus so typing replaces it (keyboard flow).
  void _onFocusGained() {
    if (widget.focusNode?.hasFocus ?? false) {
      _controller.selection =
          TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
    }
  }

  @override
  void didUpdateWidget(covariant EntryQtyStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode?.removeListener(_onFocusGained);
      widget.focusNode?.addListener(_onFocusGained);
    }
    if (oldWidget.qty != widget.qty) {
      _lastSent = widget.qty;
      final hasFocus = widget.focusNode?.hasFocus ?? false;
      if (!hasFocus) {
        _controller.text = _textFor(widget.qty);
      }
    }
  }

  @override
  void dispose() {
    widget.focusNode?.removeListener(_onFocusGained);
    _controller.dispose();
    super.dispose();
  }

  // A physical Enter key and the soft keyboard's "next" action can both fire
  // for one keypress (desktop/web); advance at most once per frame.
  bool _nextFired = false;
  void _fireNext() {
    if (_nextFired) return;
    _nextFired = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _nextFired = false);
    _commit();
    widget.onNext?.call();
  }

  // Commits the typed value once per change: the "next" action and the
  // subsequent focus loss both land here, so skip when nothing changed.
  void _commit() {
    final q = parseQty(_controller.text);
    _controller.text = _textFor(q);
    if (_lastSent == q) return;
    _lastSent = q;
    widget.onQtyEntered?.call(q);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: widget.onDecrement,
          visualDensity: VisualDensity.compact,
        ),
        SizedBox(
          width: widget.big ? 76 : 44,
          child: Focus(
            onFocusChange: (hasFocus) {
              if (!hasFocus) _commit();
            },
            // Physical Enter (desktop/web) doesn't reach onSubmitted on every
            // platform; catch it here so the flow works on a computer too.
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  (event.logicalKey == LogicalKeyboardKey.enter ||
                      event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
                _fireNext();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: TextField(
              controller: _controller,
              focusNode: widget.focusNode,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}([.,]5?)?')),
              ],
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(vertical: widget.big ? 10 : 8),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                hintText: '0',
              ),
              style: TextStyle(
                  fontSize: widget.big ? 22 : null,
                  fontWeight: FontWeight.bold,
                  color: widget.qty > 0 ? Colors.green[800] : Colors.grey),
              // Empty onEditingComplete disables the framework's own
              // focus traversal so onNext is the only thing moving focus.
              onEditingComplete: () {},
              onSubmitted: (_) => _fireNext(),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: widget.onIncrement,
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
  final double qty;
  final VoidCallback? onDecrement;
  final VoidCallback onIncrement;
  final ValueChanged<double>? onQtyEntered;
  final VoidCallback? onNext;
  final FocusNode? focusNode;
  const EntryCard({
    super.key,
    required this.name,
    required this.qty,
    required this.onDecrement,
    required this.onIncrement,
    this.onQtyEntered,
    this.onNext,
    this.focusNode,
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
              onQtyEntered: onQtyEntered,
              onNext: onNext,
              focusNode: focusNode,
            ),
          ],
        ),
      ),
    );
  }
}
