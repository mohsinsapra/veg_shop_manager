import 'package:flutter_test/flutter_test.dart';
import 'package:veg_shop_manager/data/pdf/shopping_pdf_service.dart';
import 'package:veg_shop_manager/domain/entities/catalog_item_entity.dart';
import 'package:veg_shop_manager/domain/entities/shop_entity.dart';
import 'package:veg_shop_manager/l10n/app_localizations_es.dart';

/// Regression: when the combined grid grows taller than one A4 page (many
/// items with long, wrapping names), a single pw.Page silently dropped the
/// whole table and printed only the title. MultiPage must keep the rows.
void main() {
  test('adminFullGrid keeps the table when it overflows one page', () async {
    final svc = ShoppingPdfService();
    final shops = [
      for (var i = 0; i < 5; i++)
        ShopEntity(
            id: 's$i', name: 'Shop $i', code: 'S$i', sortOrder: i, active: true),
    ];
    final catalog = [
      for (var i = 0; i < 200; i++)
        CatalogItemEntity(
          id: 'c$i',
          name: 'Pimiento Rojo Italiano Extra Grande numero $i',
          category: i < 130 ? 'Verduras' : 'Frutas',
          sortOrder: i,
          active: true,
        ),
    ];
    final qty = <String, Map<String, double>>{
      for (var i = 0; i < 200; i += 3) 'c$i': {'s${i % 5}': (i % 9) + 1.0},
    };
    final bytes = await svc.adminFullGrid(
      date: DateTime(2026, 7, 28),
      shops: shops,
      catalog: catalog,
      qtyByItemShop: qty,
      l10n: AppLocalizationsEs(),
    );
    // The dropped-table PDF was ~4 KB (title + date only); a rendered grid of
    // 200 long names is far larger. Guard with a comfortable margin.
    expect(bytes.length, greaterThan(10000));
  });
}
