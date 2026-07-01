import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../domain/entities/catalog_item_entity.dart';
import '../../domain/entities/shop_entity.dart';

/// One printable line: an item and a quantity (quantity 0 = not needed).
class PdfLine {
  final String category;
  final String itemName;
  final int quantity;
  const PdfLine(this.category, this.itemName, this.quantity);
}

/// Builds A4 PDFs that mirror the paper stock sheet. Pure functions returning
/// bytes so they are easy to unit-test and hand to the `printing` package.
///
/// Item names contain Spanish accents (Brócoli, Champiñones…). The default PDF
/// font (Helvetica) cannot render those, so callers should pass a Unicode
/// [base]/[bold] font (e.g. from `PdfGoogleFonts`); when omitted the document
/// falls back to Helvetica (fine for ASCII-only content in tests).
class ShoppingPdfService {
  final pw.Font? base;
  final pw.Font? bold;
  ShoppingPdfService({this.base, this.bold});

  final _df = DateFormat('EEE, d MMM yyyy');

  pw.Document _doc() {
    if (base == null) return pw.Document();
    return pw.Document(
      theme: pw.ThemeData.withFont(base: base!, bold: bold ?? base!),
    );
  }

  pw.Widget _header(String title, String subtitle) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title,
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.Text(subtitle, style: const pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 8),
          pw.Divider(),
        ],
      );

  /// Template 1 — a shop's compact list of only the items it needs.
  Future<Uint8List> shopCompact({
    required String shopName,
    required DateTime date,
    required List<PdfLine> lines,
  }) async {
    final needed = lines.where((l) => l.quantity > 0).toList();
    final doc = _doc();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        _header('GreenChain - $shopName', _df.format(date)),
        pw.Table(
          border: pw.TableBorder.all(width: 0.5),
          columnWidths: {0: const pw.FixedColumnWidth(40)},
          children: [
            _tableRow(['Qty', 'Item'], bold: true),
            for (final l in needed) _tableRow(['${l.quantity}', l.itemName]),
          ],
        ),
        if (needed.isEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text('Nothing needed today.'),
          ),
      ],
    ));
    return doc.save();
  }

  /// Template 2 — a shop's full catalog grid (single quantity column).
  Future<Uint8List> shopGrid({
    required String shopName,
    required DateTime date,
    required List<PdfLine> lines,
  }) async {
    final byCategory = <String, List<PdfLine>>{};
    for (final l in lines) {
      byCategory.putIfAbsent(l.category, () => []).add(l);
    }
    final doc = _doc();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        _header('GreenChain - $shopName (full sheet)', _df.format(date)),
        for (final entry in byCategory.entries) ...[
          pw.SizedBox(height: 6),
          pw.Text(entry.key,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            columnWidths: {1: const pw.FixedColumnWidth(40)},
            children: [
              for (final l in entry.value)
                _tableRow([l.itemName, l.quantity > 0 ? '${l.quantity}' : '']),
            ],
          ),
        ],
      ],
    ));
    return doc.save();
  }

  /// Template 3 — the admin combined grid: item rows by category, one column
  /// per shop (by code) plus a Total column. Mirrors the paper form.
  Future<Uint8List> adminFullGrid({
    required DateTime date,
    required List<ShopEntity> shops,
    required List<CatalogItemEntity> catalog,
    required Map<String, Map<String, int>> qtyByItemShop, // itemId -> shopId -> qty
  }) async {
    final activeShops = shops.where((s) => s.active).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final byCategory = <String, List<CatalogItemEntity>>{};
    for (final c in catalog.where((c) => c.active)) {
      byCategory.putIfAbsent(c.category, () => []).add(c);
    }

    final headerCells = ['Item', ...activeShops.map((s) => s.code), 'Total'];

    List<pw.TableRow> categoryRows(List<CatalogItemEntity> items) {
      final rows = <pw.TableRow>[];
      for (final item in items) {
        final perShop = qtyByItemShop[item.id] ?? const {};
        var total = 0;
        final cells = <String>[item.name];
        for (final s in activeShops) {
          final q = perShop[s.id] ?? 0;
          total += q;
          cells.add(q > 0 ? '$q' : '');
        }
        cells.add(total > 0 ? '$total' : '');
        rows.add(_tableRow(cells));
      }
      return rows;
    }

    final doc = _doc();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        _header('GreenChain - Combined Shopping List', _df.format(date)),
        for (final entry in byCategory.entries) ...[
          pw.SizedBox(height: 6),
          pw.Text(entry.key,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            children: [
              _tableRow(headerCells, bold: true),
              ...categoryRows(entry.value),
            ],
          ),
        ],
      ],
    ));
    return doc.save();
  }

  pw.TableRow _tableRow(List<String> cells, {bool bold = false}) => pw.TableRow(
        children: [
          for (final c in cells)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: pw.Text(c,
                  style: bold
                      ? pw.TextStyle(fontWeight: pw.FontWeight.bold)
                      : const pw.TextStyle()),
            ),
        ],
      );
}
