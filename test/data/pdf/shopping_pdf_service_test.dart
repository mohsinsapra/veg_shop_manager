import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veg_shop_manager/data/pdf/shopping_pdf_service.dart';
import 'package:veg_shop_manager/domain/entities/catalog_item_entity.dart';
import 'package:veg_shop_manager/domain/entities/shop_entity.dart';
import 'package:veg_shop_manager/l10n/app_localizations.dart';

void main() {
  final svc = ShoppingPdfService();
  final date = DateTime.utc(2026, 7, 1);
  late AppLocalizations l10n;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    l10n = await AppLocalizations.delegate.load(const Locale('es'));
  });

  bool isPdf(List<int> bytes) =>
      bytes.length > 4 &&
      bytes[0] == 0x25 && // %
      bytes[1] == 0x50 && // P
      bytes[2] == 0x44 && // D
      bytes[3] == 0x46; // F

  test('shopCompact produces a valid PDF', () async {
    final bytes = await svc.shopCompact(
      shopName: 'Downtown',
      date: date,
      lines: const [
        PdfLine('Vegetables', 'Apio', 5),
        PdfLine('Vegetables', 'Acelga', 0),
      ],
      l10n: l10n,
    );
    expect(isPdf(bytes), isTrue);
  });

  test('shopSheet produces a valid paper-format PDF', () async {
    final bytes = await svc.shopSheet(
      shopName: 'Downtown',
      shopCode: 'D',
      date: date,
      catalog: const [
        CatalogItemEntity(id: 'i1', name: 'Apio', category: 'Vegetables', sortOrder: 0, active: true),
        CatalogItemEntity(id: 'i2', name: 'Brócoli', category: 'Vegetables', sortOrder: 1, active: true),
      ],
      qtyByItem: const {'i1': 5},
      l10n: l10n,
    );
    expect(isPdf(bytes), isTrue);
  });

  test('adminFullGrid produces a valid PDF with per-shop + total columns', () async {
    final bytes = await svc.adminFullGrid(
      date: date,
      shops: const [
        ShopEntity(id: 's1', name: 'Downtown', code: 'D', sortOrder: 0, active: true),
        ShopEntity(id: 's2', name: 'Mall', code: 'M', sortOrder: 1, active: true),
      ],
      catalog: const [
        CatalogItemEntity(id: 'i1', name: 'Apio', category: 'Vegetables', sortOrder: 0, active: true),
      ],
      qtyByItemShop: const {
        'i1': {'s1': 5, 's2': 3},
      },
      l10n: l10n,
    );
    expect(isPdf(bytes), isTrue);
  });
}
