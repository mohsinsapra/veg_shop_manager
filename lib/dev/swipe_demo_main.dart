// Standalone dev harness for SwipeEntryDeck — no Firebase/login. Run with:
//   flutter run -d web-server --web-port=7357 -t lib/dev/swipe_demo_main.dart
// Not part of the app; safe to delete.
import 'package:flutter/material.dart';
import 'package:veg_shop_manager/domain/entities/catalog_item_entity.dart';
import 'package:veg_shop_manager/l10n/app_localizations.dart';
import 'package:veg_shop_manager/presentation/widgets/swipe_entry_deck.dart';

void main() => runApp(const _DemoApp());

class _DemoApp extends StatefulWidget {
  const _DemoApp();
  @override
  State<_DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends State<_DemoApp> {
  static const items = [
    CatalogItemEntity(
        id: 'a', name: 'Tomate', category: 'Verdura', sortOrder: 0, active: true),
    CatalogItemEntity(
        id: 'b', name: 'Manzana', category: 'Fruta', sortOrder: 1, active: true),
    CatalogItemEntity(
        id: 'c', name: 'Pera', category: 'Fruta', sortOrder: 2, active: true),
  ];
  final Map<String, double> qty = {};

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        appBar: AppBar(title: Text('demo qty=${qty.toString()}')),
        body: SwipeEntryDeck(
          items: items,
          qtyByItem: qty,
          onSet: (item, q) async => setState(() => qty[item.id] = q),
        ),
      ),
    );
  }
}
