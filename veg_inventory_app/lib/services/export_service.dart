import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../screens/consolidated_list_screen.dart';
import '../models/shop_model.dart';
import '../models/request_model.dart';

class ExportService {
  Future<void> exportToPDF(
    List<ConsolidatedItem> items,
    Map<String, ShopModel> shops,
    List<RequestModel> requests,
  ) async {
    final pdf = pw.Document();
    final dateStr = DateFormat('MMM dd, yyyy').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Consolidated Purchase List',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Padding(
            padding: pw.EdgeInsets.only(bottom: 20),
            child: pw.Text('Date: $dateStr'),
          ),
          pw.Text(
            'Summary',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              pw.Text('Shops: ${requests.length}'),
              pw.Text('Items: ${items.length}'),
              pw.Text('Total Requests: ${requests.fold(0, (sum, r) => sum + r.items.length)}'),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Purchase List',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(),
            columnWidths: {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(1),
              2: pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  pw.Padding(
                    padding: pw.EdgeInsets.all(8),
                    child: pw.Text('Item', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: pw.EdgeInsets.all(8),
                    child: pw.Text('Total Qty', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: pw.EdgeInsets.all(8),
                    child: pw.Text('Shop Breakdown', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ),
              ...items.map((item) {
                String breakdown = item.shopQuantities.entries
                    .map((entry) {
                      String shopName = shops[entry.key]?.name ?? 'Shop ${entry.key}';
                      return '$shopName: ${entry.value} ${item.unit}';
                    })
                    .join(', ');

                return pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: pw.EdgeInsets.all(8),
                      child: pw.Text(item.name),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(8),
                      child: pw.Text('${item.totalQuantity} ${item.unit}'),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(8),
                      child: pw.Text(breakdown, style: pw.TextStyle(fontSize: 10)),
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  Future<void> exportToCSV(
    List<ConsolidatedItem> items,
    Map<String, ShopModel> shops,
  ) async {
    List<List<dynamic>> csvData = [
      ['Item Name', 'Unit', 'Total Quantity', 'Shop Breakdown']
    ];

    for (ConsolidatedItem item in items) {
      String breakdown = item.shopQuantities.entries
          .map((entry) {
            String shopName = shops[entry.key]?.name ?? 'Shop ${entry.key}';
            return '$shopName: ${entry.value}';
          })
          .join('; ');

      csvData.add([
        item.name,
        item.unit,
        item.totalQuantity,
        breakdown,
      ]);
    }

    String csvString = const ListToCsvConverter().convert(csvData);
    
    final directory = await getApplicationDocumentsDirectory();
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final file = File('${directory.path}/purchase_list_$dateStr.csv');
    
    await file.writeAsString(csvString);
    
    await Printing.sharePdf(
      bytes: file.readAsBytesSync(),
      filename: 'purchase_list_$dateStr.csv',
    );
  }
}