import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/entities/catalog_item_entity.dart';
import 'entry_item_controls.dart';

/// Tinder-style card deck: one item at a time. Drag the top card right (or tap
/// Add) to put it on the list, left (or tap Skip) to move on. The card tilts as
/// you drag, shows ADD / SKIP overlays, and the next card peeks behind it.
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

class _SwipeEntryDeckState extends State<SwipeEntryDeck>
    with SingleTickerProviderStateMixin {
  int _i = 0;
  Offset _drag = Offset.zero;
  late final AnimationController _ctrl;
  Animation<Offset>? _anim;
  bool _addOnFinish = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 260))
      ..addListener(() {
        if (_anim != null) setState(() => _drag = _anim!.value);
      })
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _onAnimDone();
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onAnimDone() {
    final flew = _drag.dx.abs() > 100; // it flew off rather than snapping back
    if (flew) {
      final item = widget.items[_i];
      final qty = widget.qtyByItem[item.id] ?? 0;
      if (_addOnFinish && qty == 0) widget.onSet(item, 1);
      setState(() {
        _i++;
        _drag = Offset.zero;
      });
    } else {
      setState(() => _drag = Offset.zero);
    }
    _anim = null;
  }

  void _animateTo(Offset target, {required bool add}) {
    _addOnFinish = add;
    _anim = Tween(begin: _drag, end: target).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward(from: 0);
  }

  void _flyOff(double width, bool right) =>
      _animateTo(Offset(right ? width * 1.6 : -width * 1.6, _drag.dy),
          add: right);

  void _snapBack() => _animateTo(Offset.zero, add: false);

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    if (items.isEmpty) return const Center(child: Text('No items.'));
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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                    value: (_i + 1) / items.length, minHeight: 6),
              ),
              const SizedBox(width: 12),
              Text('${_i + 1} / ${items.length}'),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Next card peeking behind.
                  if (_i + 1 < items.length)
                    Transform.scale(
                      scale: 0.94,
                      child: Opacity(
                        opacity: 0.6,
                        child: _cardShell(items[_i + 1],
                            widget.qtyByItem[items[_i + 1].id] ?? 0,
                            interactive: false),
                      ),
                    ),
                  // Top, draggable card.
                  GestureDetector(
                    onPanUpdate: (d) => setState(() => _drag += d.delta),
                    onPanEnd: (_) {
                      if (_drag.dx.abs() > w * 0.28) {
                        _flyOff(w, _drag.dx > 0);
                      } else {
                        _snapBack();
                      }
                    },
                    child: Transform.translate(
                      offset: _drag,
                      child: Transform.rotate(
                        angle: (_drag.dx / w) * 0.35,
                        child: _cardShell(item, qty, interactive: true),
                      ),
                    ),
                  ),
                ],
              );
            },
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
                onPressed:
                    _i > 0 ? () => setState(() => _i--) : null,
              ),
              FilledButton.icon(
                icon: const Icon(Icons.close),
                label: const Text('Skip'),
                style: FilledButton.styleFrom(backgroundColor: Colors.blueGrey),
                onPressed: () => setState(() => _i++),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('Add'),
                onPressed: () {
                  if (qty == 0) widget.onSet(item, 1);
                  setState(() => _i++);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cardShell(CatalogItemEntity item, int qty, {required bool interactive}) {
    final active = qty > 0;
    // Overlay strength based on horizontal drag (only for the top card).
    final t = interactive ? (_drag.dx / 140).clamp(-1.0, 1.0) : 0.0;
    return LayoutBuilder(
      builder: (context, c) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: active
                  ? const BorderSide(color: Colors.green, width: 2)
                  : BorderSide(color: Colors.grey.shade300),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(item.category,
                            style: TextStyle(color: Colors.grey[500])),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            item.name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 30, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      EntryQtyStepper(
                        qty: qty,
                        onDecrement:
                            qty > 0 ? () => widget.onSet(item, qty - 1) : null,
                        onIncrement: () => widget.onSet(item, qty + 1),
                      ),
                      const SizedBox(height: 6),
                      Text('Drag →  add     ←  skip',
                          style:
                              TextStyle(color: Colors.grey[500], fontSize: 12)),
                    ],
                  ),
                ),
                if (t > 0.05) _overlay('ADD', Colors.green, t, Alignment.topLeft),
                if (t < -0.05)
                  _overlay('SKIP', Colors.blueGrey, -t, Alignment.topRight),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _overlay(String label, Color color, double opacity, Alignment align) {
    return Positioned.fill(
      child: Align(
        alignment: align,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Opacity(
            opacity: math.min(1.0, opacity),
            child: Transform.rotate(
              angle: align == Alignment.topLeft ? -0.3 : 0.3,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: color, width: 3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 26,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
