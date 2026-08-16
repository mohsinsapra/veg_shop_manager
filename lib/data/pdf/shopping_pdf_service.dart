import 'dart:math' as math;
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:veg_shop_manager/l10n/app_localizations.dart';
import '../../core/utils/qty_format.dart';
import '../../domain/entities/catalog_item_entity.dart';
import '../../domain/entities/shop_entity.dart';

/// Which columns the combined admin grid should include.
enum GridTotalMode { shopsAndTotal, totalOnly, shopsOnly }

/// One printable line: an item and a quantity (quantity 0 = not needed).
class PdfLine {
  final String category;
  final String itemName;
  final double quantity;
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

  // Weekday/month abbreviations so the date reads correctly in the app locale
  // without depending on intl locale data being initialized at runtime.
  static const _esDays = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
  static const _esMonths = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];
  static const _enDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _enMonths = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _fmtDate(DateTime d, AppLocalizations l10n) {
    final isEs = l10n.localeName == 'es';
    final days = isEs ? _esDays : _enDays;
    final months = isEs ? _esMonths : _enMonths;
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
  }

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
    required AppLocalizations l10n,
  }) {
    const blocks = 3;
    final perCol = math.max(1, (rows.length / blocks).ceil());
    final valueCols = columnHeaders.length;
    final perBlock = 1 + valueCols; // item name + value columns

    // `shrinkToFit` keeps long item names on ONE line by scaling them down
    // instead of wrapping: a wrapped name doubles its row's height, which is
    // what used to push the grid onto a second page.
    pw.Widget cell(String text,
        {bool bold = false, bool header = false, bool shrinkToFit = false}) {
      final txt = pw.Text(
        text,
        style: pw.TextStyle(
            fontSize: 9,
            fontWeight:
                (bold || header) ? pw.FontWeight.bold : pw.FontWeight.normal),
      );
      return pw.Container(
        alignment: header ? pw.Alignment.center : pw.Alignment.centerLeft,
        padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2.2),
        child: shrinkToFit
            ? pw.FittedBox(fit: pw.BoxFit.scaleDown, child: txt)
            : txt,
      );
    }

    // Header row repeated for each block. The item column is headed like the
    // paper sheet: the first two blocks are vegetables (VERDURAS), the last is
    // fruit (FRUTAS).
    final blockTitles = [
      l10n.pdfVegetables.toUpperCase(),
      l10n.pdfVegetables.toUpperCase(),
      l10n.pdfFruits.toUpperCase(),
    ];
    final header = <pw.Widget>[];
    for (var b = 0; b < blocks; b++) {
      header.add(cell(blockTitles[b], bold: true));
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
          cells.add(cell(rows[idx].name, shrinkToFit: true));
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
          : const pw.FixedColumnWidth(17);
    }

    final doc = _doc();
    // MultiPage, not Page: a single fixed page silently DROPS the whole table
    // when it grows past one A4 (more catalog items / wrapped names), printing
    // just the title. MultiPage keeps one page when it fits and flows extra
    // rows onto a second page when it doesn't.
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(12),
      build: (context) => [
        pw.Text(title,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.Text(_fmtDate(date, l10n), style: const pw.TextStyle(fontSize: 9)),
        pw.SizedBox(height: 5),
        pw.Table(
          border: pw.TableBorder.all(width: 0.4, color: PdfColors.grey700),
          columnWidths: widths,
          children: tableRows,
        ),
      ],
    ));
    return doc.save();
  }

  /// Admin combined grid — one column per active shop (by code) + Total.
  Future<Uint8List> adminFullGrid({
    required DateTime date,
    required List<ShopEntity> shops,
    required List<CatalogItemEntity> catalog,
    required Map<String, Map<String, double>> qtyByItemShop, // itemId -> shopId -> qty
    required AppLocalizations l10n,
    GridTotalMode totalMode = GridTotalMode.shopsAndTotal,
  }) async {
    final activeShops = shops.where((s) => s.active).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final headers = switch (totalMode) {
      GridTotalMode.shopsAndTotal => [...activeShops.map((s) => s.code), 'T'],
      GridTotalMode.shopsOnly => [...activeShops.map((s) => s.code)],
      GridTotalMode.totalOnly => ['T'],
    };
    final rows = [
      for (final item in _ordered(catalog))
        _buildComboRow(item, activeShops, qtyByItemShop[item.id] ?? const {},
            totalMode),
    ];
    return _paperGrid(
      title: 'Frutas Deliciosas - ${l10n.pdfCombinedTitle}',
      date: date,
      columnHeaders: headers,
      rows: rows,
      l10n: l10n,
    );
  }

  _PaperRow _buildComboRow(CatalogItemEntity item, List<ShopEntity> shops,
      Map<String, double> perShop, GridTotalMode totalMode) {
    var total = 0.0;
    final shopCells = <String>[];
    for (final s in shops) {
      final q = perShop[s.id] ?? 0;
      total += q;
      shopCells.add(q > 0 ? fmtQty(q) : '');
    }
    final cells = switch (totalMode) {
      GridTotalMode.shopsAndTotal => [...shopCells, total > 0 ? fmtQty(total) : ''],
      GridTotalMode.shopsOnly => shopCells,
      GridTotalMode.totalOnly => [total > 0 ? fmtQty(total) : ''],
    };
    return _PaperRow(item.name, cells);
  }

  /// One shop's full sheet — the same paper layout with a single quantity
  /// column headed by the shop code.
  Future<Uint8List> shopSheet({
    required String shopName,
    required String shopCode,
    required DateTime date,
    required List<CatalogItemEntity> catalog,
    required Map<String, double> qtyByItem,
    required AppLocalizations l10n,
  }) async {
    final rows = [
      for (final item in _ordered(catalog))
        _PaperRow(item.name,
            [(qtyByItem[item.id] ?? 0) > 0 ? fmtQty(qtyByItem[item.id]!) : '']),
    ];
    return _paperGrid(
      title: 'Frutas Deliciosas - $shopName',
      date: date,
      columnHeaders: [shopCode.isEmpty ? l10n.pdfQtyHeader : shopCode],
      rows: rows,
      l10n: l10n,
    );
  }

  /// A shop's compact list of only the items it needs (quick loading list).
  Future<Uint8List> shopCompact({
    required String shopName,
    required DateTime date,
    required List<PdfLine> lines,
    required AppLocalizations l10n,
  }) async {
    final needed = lines.where((l) => l.quantity > 0).toList()
      ..sort((a, b) => a.itemName.compareTo(b.itemName));
    final doc = _doc();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Text('Frutas Deliciosas - $shopName',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.Text(_fmtDate(date, l10n), style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(width: 0.5),
          columnWidths: {0: const pw.FixedColumnWidth(40)},
          children: [
            pw.TableRow(children: [
              pw.Padding(
                  padding: const pw.EdgeInsets.all(3),
                  child: pw.Text(l10n.pdfQtyHeader,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
              pw.Padding(
                  padding: const pw.EdgeInsets.all(3),
                  child: pw.Text(l10n.pdfProductHeader,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
            ]),
            for (final l in needed)
              pw.TableRow(children: [
                pw.Padding(
                    padding: const pw.EdgeInsets.all(3),
                    child: pw.Text(fmtQty(l.quantity))),
                pw.Padding(
                    padding: const pw.EdgeInsets.all(3), child: pw.Text(l.itemName)),
              ]),
          ],
        ),
        if (needed.isEmpty)
          pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(l10n.pdfNothingNeeded)),
      ],
    ));
    return doc.save();
  }
}
