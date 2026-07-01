import 'dart:typed_data';
import 'package:printing/printing.dart';
import '../../data/pdf/shopping_pdf_service.dart';

/// Builds a PDF service with Unicode fonts so Spanish accents render. Fonts are
/// fetched from Google Fonts on first use and cached by the `printing` package.
Future<ShoppingPdfService> buildPdfService() async {
  final base = await PdfGoogleFonts.notoSansRegular();
  final bold = await PdfGoogleFonts.notoSansBold();
  return ShoppingPdfService(base: base, bold: bold);
}

/// Opens the platform print / share dialog for the given PDF bytes (prints on
/// desktop/mobile, uses the browser print dialog on web).
Future<void> printBytes(Uint8List bytes, {String name = 'greenchain.pdf'}) {
  return Printing.layoutPdf(onLayout: (_) async => bytes, name: name);
}
