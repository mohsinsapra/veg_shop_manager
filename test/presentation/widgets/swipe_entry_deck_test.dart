import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veg_shop_manager/domain/entities/catalog_item_entity.dart';
import 'package:veg_shop_manager/l10n/app_localizations.dart';
import 'package:veg_shop_manager/presentation/widgets/swipe_entry_deck.dart';

void main() {
  // These tests exercise the desktop flow (focused TextField + keyboard).
  // Under `flutter test` the default platform is Android, which now renders
  // the custom keypad instead, so pin a desktop platform per test. The
  // override must be back to null before each test body ends (the binding
  // asserts foundation vars are unset), hence the helper.
  Future<void> onDesktop(
    WidgetTester tester,
    Future<void> Function() body,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  const items = [
    CatalogItemEntity(
      id: 'a',
      name: 'Tomate',
      category: 'Verdura',
      sortOrder: 0,
      active: true,
    ),
    CatalogItemEntity(
      id: 'b',
      name: 'Manzana',
      category: 'Fruta',
      sortOrder: 1,
      active: true,
    ),
    CatalogItemEntity(
      id: 'c',
      name: 'Pera',
      category: 'Fruta',
      sortOrder: 2,
      active: true,
    ),
  ];

  testWidgets(
    'typing a qty and pressing next advances the deck focused',
    (tester) async => onDesktop(tester, () async {
      final set = <String, double>{};
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SwipeEntryDeck(
              items: items,
              qtyByItem: const {},
              onSet: (item, q) async => set[item.id] = q,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The top card's field should be auto-focused.
      final topField = find.byWidgetPredicate(
        (w) => w is TextField && w.focusNode != null,
      );
      expect(
        tester.widget<TextField>(topField).focusNode?.hasFocus,
        isTrue,
        reason: 'top card qty field should be auto-focused',
      );

      // Type a quantity and press the keyboard "next" action.
      await tester.enterText(topField, '2,5');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();

      // Value committed and deck advanced to the second card.
      expect(set['a'], 2.5);
      expect(find.text('Manzana'), findsWidgets);

      // The new top card's field should be focused again.
      final newTop = find.byWidgetPredicate(
        (w) => w is TextField && w.focusNode != null,
      );
      expect(
        tester.widget<TextField>(newTop).focusNode?.hasFocus,
        isTrue,
        reason: 'focus should follow to the next card',
      );

      // And typing straight away should commit to the second item.
      await tester.enterText(newTop, '3');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      expect(set['b'], 3);
      expect(find.text('Pera'), findsWidgets);
    }),
  );

  testWidgets(
    'hardware Enter key advances the deck (desktop path)',
    (tester) async => onDesktop(tester, () async {
      final set = <String, double>{};
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SwipeEntryDeck(
              items: items,
              qtyByItem: const {},
              onSet: (item, q) async => set[item.id] = q,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final topField = find.byWidgetPredicate(
        (w) => w is TextField && w.focusNode != null,
      );
      await tester.enterText(topField, '4');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(set['a'], 4, reason: 'Enter should commit the typed value');
      expect(
        find.text('Manzana'),
        findsWidgets,
        reason: 'Enter should advance to the next card',
      );
      final newTop = find.byWidgetPredicate(
        (w) => w is TextField && w.focusNode != null,
      );
      expect(
        tester.widget<TextField>(newTop).focusNode?.hasFocus,
        isTrue,
        reason: 'focus should follow to the next card',
      );
    }),
  );

  testWidgets('mobile keypad enter with no value advances WITHOUT adding', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final set = <String, double>{};
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SwipeEntryDeck(
              items: items,
              qtyByItem: const {},
              onSet: (item, q) async => set[item.id] = q,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter with an empty quantity: card advances, nothing is added.
      await tester.tap(find.byIcon(Icons.keyboard_return));
      await tester.pumpAndSettle();
      expect(set, isEmpty, reason: 'zero/empty enter must not add the item');
      expect(find.text('Manzana'), findsWidgets);

      // Typing a quantity on the keypad and pressing enter DOES add it.
      await tester.tap(find.text('3').last); // keypad digit key
      await tester.tap(find.byIcon(Icons.keyboard_return));
      await tester.pumpAndSettle();
      expect(set['b'], 3);
      expect(find.text('Pera'), findsWidgets);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
