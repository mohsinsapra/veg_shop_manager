import 'dart:math' as math;
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

/// A single grid row: item name plus one text cell per value column.
class _PaperRow {
  final String name;
  final List<String> cells;
  const _PaperRow(this.name, this.cells);
}

/// Builds A4 PDFs that mirror the paper stock sheet: the full item list laid
/// out in three side-by-side blocks on ONE page, with a shop column per shop
/// (by code) and a Total column. Per-shop prints use the same layout with a
/// single quantity column.
///
/// Item names contain Spanish accents; pass a Unicode [base]/[bold] font
/// (e.g. from `PdfGoogleFonts`) or the document falls back to Helvetica.
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

  List<CatalogItemEntity> _ordered(List<CatalogItemEntity> catalog) =>
      catalog.where((c) => c.active).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  /// Core single-page grid: ONE continuous table with three item-blocks laid
  /// side by side (like the paper), so there are no gaps between sub-tables.
  /// Each block is: Item | <value columns> (e.g. L S T P Total).
  Future<Uint8List> _paperGrid({
    required String title,
    required DateTime date,
    required List<String> columnHeaders,
    required List<_PaperRow> rows,
  }) {
    const blocks = 3;
    final perCol = math.max(1, (rows.length / blocks).ceil());
    final valueCols = columnHeaders.length;
    final perBlock = 1 + valueCols; // item name + value columns

    pw.Widget cell(String text, {bool bold = false, bool header = false}) =>
        pw.Container(
          alignment: header ? pw.Alignment.center : pw.Alignment.centerLeft,
          padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 1.2),
          child: pw.Text(
            text,
            style: pw.TextStyle(
                fontSize: 6.2,
                fontWeight:
                    (bold || header) ? pw.FontWeight.bold : pw.FontWeight.normal),
          ),
        );

    // Header row repeated for each block.
    final header = <pw.Widget>[];
    for (var b = 0; b < blocks; b++) {
      header.add(cell('Item', bold: true));
      for (final h in columnHeaders) {
        header.add(cell(h, header: true));
      }
    }

    final tableRows = <pw.TableRow>[pw.TableRow(children: header)];
    for (var i = 0; i < perCol; i++) {
      final cells = <pw.Widget>[];
      for (var b = 0; b < blocks; b++) {
        final idx = b * perCol + i;
        if (idx < rows.length) {
          cells.add(cell(rows[idx].name));
          for (final c in rows[idx].cells) {
            cells.add(cell(c, header: true));
          }
        } else {
          for (var k = 0; k < perBlock; k++) {
            cells.add(cell(''));
          }
        }
      }
      tableRows.add(pw.TableRow(children: cells));
    }

    final widths = <int, pw.TableColumnWidth>{};
    for (var c = 0; c < perBlock * blocks; c++) {
      widths[c] = (c % perBlock == 0)
          ? const pw.FlexColumnWidth(2.4)
          : const pw.FixedColumnWidth(11);
    }

    final doc = _doc();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(12),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title,
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.Text(_df.format(date), style: const pw.TextStyle(fontSize: 8)),
          pw.SizedBox(height: 4),
          pw.Table(
            border: pw.TableBorder.all(width: 0.4, color: PdfColors.grey700),
            columnWidths: widths,
            children: tableRows,
          ),
        ],
      ),
    ));
    return doc.save();
  }

  /// Admin combined grid — one column per active shop (by code) + Total.
  Future<Uint8List> adminFullGrid({
    required DateTime date,
    required List<ShopEntity> shops,
    required List<CatalogItemEntity> catalog,
    required Map<String, Map<String, int>> qtyByItemShop, // itemId -> shopId -> qty
  }) async {
    final activeShops = shops.where((s) => s.active).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final headers = [...activeShops.map((s) => s.code), 'T'];
    final rows = [
      for (final item in _ordered(catalog))
        _buildComboRow(item, activeShops, qtyByItemShop[item.id] ?? const {}),
    ];
    return _paperGrid(
      title: 'GreenChain - Combined Shopping List',
      date: date,
      columnHeaders: headers,
      rows: rows,
    );
  }

  _PaperRow _buildComboRow(CatalogItemEntity item, List<ShopEntity> shops,
      Map<String, int> perShop) {
    var total = 0;
    final cells = <String>[];
    for (final s in shops) {
      final q = perShop[s.id] ?? 0;
      total += q;
      cells.add(q > 0 ? '$q' : '');
    }
    cells.add(total > 0 ? '$total' : '');
    return _PaperRow(item.name, cells);
  }

  /// One shop's full sheet — the same paper layout with a single quantity
  /// column headed by the shop code.
  Future<Uint8List> shopSheet({
    required String shopName,
    required String shopCode,
    required DateTime date,
    required List<CatalogItemEntity> catalog,
    required Map<String, int> qtyByItem,
  }) async {
    final rows = [
      for (final item in _ordered(catalog))
        _PaperRow(item.name,
            [(qtyByItem[item.id] ?? 0) > 0 ? '${qtyByItem[item.id]}' : '']),
    ];
    return _paperGrid(
      title: 'GreenChain - $shopName',
      date: date,
      columnHeaders: [shopCode.isEmpty ? 'Qty' : shopCode],
      rows: rows,
    );
  }

  /// A shop's compact list of only the items it needs (quick loading list).
  Future<Uint8List> shopCompact({
    required String shopName,
    required DateTime date,
    required List<PdfLine> lines,
  }) async {
    final needed = lines.where((l) => l.quantity > 0).toList()
      ..sort((a, b) => a.itemName.compareTo(b.itemName));
    final doc = _doc();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Text('GreenChain - $shopName',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.Text(_df.format(date), style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(width: 0.5),
          columnWidths: {0: const pw.FixedColumnWidth(40)},
          children: [
            pw.TableRow(children: [
              pw.Padding(
                  padding: const pw.EdgeInsets.all(3),
                  child: pw.Text('Qty',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
              pw.Padding(
                  padding: const pw.EdgeInsets.all(3),
                  child: pw.Text('Item',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
            ]),
            for (final l in needed)
              pw.TableRow(children: [
                pw.Padding(
                    padding: const pw.EdgeInsets.all(3),
                    child: pw.Text('${l.quantity}')),
                pw.Padding(
                    padding: const pw.EdgeInsets.all(3), child: pw.Text(l.itemName)),
              ]),
          ],
        ),
        if (needed.isEmpty)
          pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text('Nothing needed today.')),
      ],
    ));
    return doc.save();
  }
}
