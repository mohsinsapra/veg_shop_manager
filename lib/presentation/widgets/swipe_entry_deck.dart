import 'dart:math' as math;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/item_images.dart';
import '../../core/l10n/l10n_extension.dart';
import '../../domain/entities/catalog_item_entity.dart';
import 'entry_item_controls.dart';

/// Tinder-style card deck: one item at a time. Drag the top card right (or tap
/// Add) to put it on the list, left (or tap Skip) to move on. The card tilts as
/// you drag, shows ADD / SKIP overlays, and the next card peeks behind it.
class SwipeEntryDeck extends StatefulWidget {
  final List<CatalogItemEntity> items;
  final Map<String, double> qtyByItem;
  final Future<void> Function(CatalogItemEntity item, double qty) onSet;

  /// When true the product photo fills the card as a background (owner
  /// setting; defaults to text-only).
  final bool showImages;

  /// When true, hides the progress row and the bottom action buttons so the
  /// card gets maximum vertical space (used while the soft keyboard is open).
  final bool compact;
  const SwipeEntryDeck({
    super.key,
    required this.items,
    required this.qtyByItem,
    required this.onSet,
    this.showImages = false,
    this.compact = false,
  });

  @override
  State<SwipeEntryDeck> createState() => SwipeEntryDeckState();
}

class SwipeEntryDeckState extends State<SwipeEntryDeck>
    with SingleTickerProviderStateMixin {
  int _i = 0;
  Offset _drag = Offset.zero;
  late final AnimationController _ctrl;
  Animation<Offset>? _anim;
  bool _addOnFinish = false;

  // One focus node per item: focus must genuinely MOVE between nodes when the
  // deck advances — re-requesting an already-focused shared node is a no-op,
  // which on web leaves the fresh TextField without a text input connection
  // (typed characters vanish while raw keys still arrive).
  final Map<String, FocusNode> _qtyFocus = {};

  FocusNode _focusFor(String id) => _qtyFocus.putIfAbsent(id, FocusNode.new);

  // Mobile (incl. mobile browsers) gets a custom in-app numeric keypad
  // instead of the system keyboard: no focus node is ever requested, and the
  // qty field is fed by a controller the keypad keys mutate directly.
  static final bool _isMobile =
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;
  final _kbCtrl = TextEditingController();
  bool _replaceOnNextKey = true;
  static final RegExp _qtyPattern = RegExp(r'^\d{0,3}([.,]5?)?$');

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 260),
          )
          ..addListener(() {
            if (_anim != null) setState(() => _drag = _anim!.value);
          })
          ..addStatusListener((s) {
            if (s == AnimationStatus.completed) _onAnimDone();
          });
    _focusQty();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _kbCtrl.dispose();
    for (final node in _qtyFocus.values) {
      node.dispose();
    }
    super.dispose();
  }

  /// Puts the top card's quantity field in focus so the member can type the
  /// amount straight away (keyboard stays up while advancing through cards).
  void _focusQty() {
    // On mobile the qty field is read-only and fed by the in-app keypad;
    // nothing should ever take focus (that would pop the system keyboard).
    if (_isMobile) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _i < widget.items.length) {
        _focusFor(widget.items[_i].id).requestFocus();
      }
    });
  }

  void _goTo(int index) {
    setState(() => _i = index);
    _replaceOnNextKey = true;
    _focusQty();
  }

  /// Jumps directly to the card for [id] (used when the admin taps a search
  /// suggestion). No-op if the item isn't in the current deck.
  void jumpToItem(String id, {bool activate = false}) {
    final idx = widget.items.indexWhere((it) => it.id == id);
    if (idx == -1) return;
    // When picked from search the intent is clearly "I need this item": put
    // it on the list right away so the card lights up as active.
    if (activate && (widget.qtyByItem[id] ?? 0) == 0) {
      widget.onSet(widget.items[idx], 1);
    }
    _ctrl.stop();
    _anim = null;
    setState(() {
      _i = idx;
      _drag = Offset.zero;
    });
    _replaceOnNextKey = true;
    _focusQty();
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
      _replaceOnNextKey = true;
      _focusQty();
    } else {
      setState(() => _drag = Offset.zero);
    }
    _anim = null;
  }

  void _animateTo(Offset target, {required bool add}) {
    _addOnFinish = add;
    _anim = Tween(
      begin: _drag,
      end: target,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward(from: 0);
  }

  void _flyOff(double width, bool right) => _animateTo(
    Offset(right ? width * 1.6 : -width * 1.6, _drag.dy),
    add: right,
  );

  void _snapBack() => _animateTo(Offset.zero, add: false);

  // --- In-app numeric keypad (mobile only) -------------------------------

  void _keyDigit(String d) {
    final base = _replaceOnNextKey ? '' : _kbCtrl.text;
    final candidate = base + d;
    if (!_qtyPattern.hasMatch(candidate)) return;
    _replaceOnNextKey = false;
    _kbCtrl.text = candidate;
  }

  void _keyComma() {
    final base = _replaceOnNextKey ? '' : _kbCtrl.text;
    final candidate = '$base,';
    if (!_qtyPattern.hasMatch(candidate)) return;
    _replaceOnNextKey = false;
    _kbCtrl.text = candidate;
  }

  void _keyBackspace() {
    _replaceOnNextKey = false;
    final text = _kbCtrl.text;
    if (text.isEmpty) return;
    _kbCtrl.text = text.substring(0, text.length - 1);
  }

  void _keySkip() => _goTo(_i + 1);

  void _keyEnter() {
    final item = widget.items[_i];
    final q = parseQty(_kbCtrl.text);
    final current = widget.qtyByItem[item.id] ?? 0;
    if (q > 0) {
      if (q != current) widget.onSet(item, q);
    } else if (current == 0) {
      widget.onSet(item, 1);
    }
    _goTo(_i + 1);
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    if (items.isEmpty) return Center(child: Text(context.l10n.swipeNoItems));
    if (_i >= items.length) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green[600]),
            const SizedBox(height: 12),
            Text(context.l10n.swipeAllReviewed),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.replay),
              label: Text(context.l10n.swipeStartOver),
              onPressed: () => _goTo(0),
            ),
          ],
        ),
      );
    }

    final item = items[_i];
    final qty = widget.qtyByItem[item.id] ?? 0;

    return Column(
      children: [
        // Visibility (not `if`) so the Column's child list never changes
        // length: removing children re-slots the Expanded card area, which
        // rebuilds the focused qty field and closes the keyboard in a loop.
        // On mobile the keypad's nav strip already shows the position, so the
        // progress row is desktop-only — the card gets the extra height.
        Visibility(
          visible: !widget.compact && !_isMobile,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
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
                        child: _cardShell(
                          items[_i + 1],
                          widget.qtyByItem[items[_i + 1].id] ?? 0,
                          interactive: false,
                        ),
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
        Visibility(
          visible: !widget.compact && !_isMobile,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ExcludeFocus(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton.filledTonal(
                    icon: const Icon(Icons.chevron_left),
                    tooltip: context.l10n.swipePrevious,
                    onPressed: _i > 0 ? () => _goTo(_i - 1) : null,
                  ),
                  FilledButton.icon(
                    icon: const Icon(Icons.close),
                    label: Text(context.l10n.swipeSkip),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
                    ),
                    onPressed: () => _goTo(_i + 1),
                  ),
                  FilledButton.icon(
                    icon: const Icon(Icons.check),
                    label: Text(context.l10n.swipeAdd),
                    onPressed: () {
                      if (qty == 0) widget.onSet(item, 1);
                      _goTo(_i + 1);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        // Keyboard accessory bar: iOS's numeric pad has no enter key, so while
        // the keyboard is open (compact mode) this row sits directly above it
        // and acts as the enter key — add & advance without closing the
        // keyboard. Visibility (not `if`) to keep the child list stable.
        Visibility(
          visible: widget.compact && !_isMobile,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: Border(
                top: BorderSide(color: Colors.grey.shade400, width: 0.5),
              ),
            ),
            // ExcludeFocus: if these buttons could take focus, tapping them
            // would blur the qty field and iOS would close the keyboard.
            child: ExcludeFocus(
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => _goTo(_i + 1),
                    child: Text(context.l10n.swipeSkip),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.keyboard_return),
                      label: Text(context.l10n.swipeAdd),
                      onPressed: () {
                        if (qty == 0) widget.onSet(item, 1);
                        _goTo(_i + 1);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_isMobile)
          // Hidden while the system keyboard is up (compact = search focused):
          // two stacked keyboards would bury the card entirely.
          Visibility(
            visible: !widget.compact,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Prev / next navigation strip above the keypad.
                  Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                    child: Row(
                      children: [
                        IconButton.filledTonal(
                          icon: const Icon(Icons.chevron_left),
                          tooltip: context.l10n.swipePrevious,
                          onPressed: _i > 0 ? () => _goTo(_i - 1) : null,
                        ),
                        Expanded(
                          child: Text(
                            '${_i + 1} / ${items.length}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: () => _goTo(_i + 1),
                        ),
                      ],
                    ),
                  ),
                  _QtyKeypad(
                    onDigit: _keyDigit,
                    onComma: _keyComma,
                    onBackspace: _keyBackspace,
                    onSkip: _keySkip,
                    onEnter: _keyEnter,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _cardShell(
    CatalogItemEntity item,
    double qty, {
    required bool interactive,
  }) {
    final active = qty > 0;
    // Overlay strength based on horizontal drag (only for the top card).
    final t = interactive ? (_drag.dx / 140).clamp(-1.0, 1.0) : 0.0;
    final photoUrl = !widget.showImages
        ? ''
        : (item.imageUrl.isNotEmpty
              ? item.imageUrl
              : (ItemImages.byName[item.name] ?? ''));
    final onPhoto = photoUrl.isNotEmpty;
    return LayoutBuilder(
      builder: (context, c) {
        // Responsive: on short cards (mobile with the keypad docked, or the
        // soft keyboard open) shrink chrome so the item name keeps its space.
        final tight = widget.compact || c.maxHeight < 380;
        return Padding(
          padding: EdgeInsets.all(tight ? 8 : 16),
          child: Card(
            elevation: 4,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: active
                  ? const BorderSide(color: Colors.green, width: 2)
                  : BorderSide(color: Colors.grey.shade300),
            ),
            child: Stack(
              children: [
                // Full-card product photo with a darkening gradient so the
                // name and controls stay readable on any picture.
                if (onPhoto) ...[
                  Positioned.fill(
                    child: Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) =>
                          const SizedBox.shrink(),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.35),
                            Colors.black.withValues(alpha: 0.05),
                            Colors.black.withValues(alpha: 0.55),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                Padding(
                  padding: EdgeInsets.all(tight ? 12 : 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          item.category,
                          style: TextStyle(
                            color: onPhoto
                                ? Colors.white.withValues(alpha: 0.9)
                                : Colors.grey[500],
                          ),
                        ),
                      ),
                      Expanded(
                        // FittedBox scales the (possibly wrapped) name down
                        // instead of letting it clip when the card is short.
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: math.max(120, c.maxWidth - 96),
                              ),
                              child: Text(
                                item.name,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: tight ? 26 : 30,
                                  fontWeight: FontWeight.bold,
                                  color: onPhoto ? Colors.white : null,
                                  shadows: onPhoto
                                      ? const [
                                          Shadow(
                                            color: Colors.black54,
                                            blurRadius: 12,
                                            offset: Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        padding: onPhoto
                            ? const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 4,
                              )
                            : EdgeInsets.zero,
                        decoration: onPhoto
                            ? BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.88),
                                borderRadius: BorderRadius.circular(16),
                              )
                            : null,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            EntryQtyStepper(
                              key: ValueKey(item.id),
                              qty: qty,
                              big: true,
                              controller: interactive && _isMobile
                                  ? _kbCtrl
                                  : null,
                              readOnly: interactive && _isMobile,
                              focusNode: interactive && !_isMobile
                                  ? _focusFor(item.id)
                                  : null,
                              onDecrement: qty > 0
                                  ? () => widget.onSet(
                                      item,
                                      (qty - 1)
                                          .clamp(0, double.infinity)
                                          .toDouble(),
                                    )
                                  : null,
                              onIncrement: () => widget.onSet(item, qty + 1),
                              onQtyEntered: interactive
                                  ? (v) => widget.onSet(item, v)
                                  : null,
                              onNext: interactive ? () => _goTo(_i + 1) : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (t > 0.05)
                  _overlay(
                    context.l10n.swipeOverlayAdd,
                    Colors.green,
                    t,
                    Alignment.topLeft,
                  ),
                if (t < -0.05)
                  _overlay(
                    context.l10n.swipeOverlaySkip,
                    Colors.blueGrey,
                    -t,
                    Alignment.topRight,
                  ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: color, width: 3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The custom in-app numeric keypad shown on mobile in place of the system
/// keyboard: digits 1-9, comma, 0, backspace on the left; skip and enter
/// (add & advance) on the right.
class _QtyKeypad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onComma;
  final VoidCallback onBackspace;
  final VoidCallback onSkip;
  final VoidCallback onEnter;
  const _QtyKeypad({
    required this.onDigit,
    required this.onComma,
    required this.onBackspace,
    required this.onSkip,
    required this.onEnter,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Scale with the viewport so small phones keep room for the card.
    final keypadHeight = (MediaQuery.sizeOf(context).height * 0.28).clamp(
      170.0,
      230.0,
    );
    return Container(
      height: keypadHeight,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        border: Border(
          top: BorderSide(color: Colors.grey.shade400, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      _digitKey(context, '1'),
                      _digitKey(context, '2'),
                      _digitKey(context, '3'),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      _digitKey(context, '4'),
                      _digitKey(context, '5'),
                      _digitKey(context, '6'),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      _digitKey(context, '7'),
                      _digitKey(context, '8'),
                      _digitKey(context, '9'),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      _commaKey(context),
                      _digitKey(context, '0'),
                      _backspaceKey(context),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Expanded(
                  flex: 1,
                  child: _actionKey(
                    context,
                    icon: Icons.close,
                    background: Colors.blueGrey.withValues(alpha: 0.15),
                    iconColor: Colors.blueGrey,
                    tooltip: context.l10n.swipeSkip,
                    onTap: onSkip,
                  ),
                ),
                const SizedBox(height: 3),
                Expanded(
                  flex: 3,
                  child: _actionKey(
                    context,
                    icon: Icons.keyboard_return,
                    background: Colors.green[700]!,
                    iconColor: Colors.white,
                    tooltip: context.l10n.swipeAdd,
                    onTap: onEnter,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _key(
    BuildContext context, {
    required Widget child,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              HapticFeedback.lightImpact();
              onTap();
            },
            child: Center(child: child),
          ),
        ),
      ),
    );
  }

  Widget _digitKey(BuildContext context, String d) {
    return _key(
      context,
      onTap: () => onDigit(d),
      child: Text(
        d,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _commaKey(BuildContext context) {
    return _key(
      context,
      onTap: onComma,
      child: const Text(
        ',',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _backspaceKey(BuildContext context) {
    return _key(
      context,
      onTap: onBackspace,
      child: const Icon(Icons.backspace_outlined, size: 22),
    );
  }

  Widget _actionKey(
    BuildContext context, {
    required IconData icon,
    required Color background,
    required Color iconColor,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              HapticFeedback.lightImpact();
              onTap();
            },
            child: Center(child: Icon(icon, color: iconColor)),
          ),
        ),
      ),
    );
  }
}
