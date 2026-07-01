import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:veg_shop_manager/core/l10n/l10n_extension.dart';
import 'package:veg_shop_manager/l10n/app_localizations.dart';
import '../../data/pdf/shopping_pdf_service.dart';

/// Builds a PDF service with Unicode fonts so Spanish accents render. Fonts are
/// fetched from Google Fonts on first use and cached by the `printing` package.
Future<ShoppingPdfService> buildPdfService() async {
  final base = await PdfGoogleFonts.notoSansRegular();
  final bold = await PdfGoogleFonts.notoSansBold();
  return ShoppingPdfService(base: base, bold: bold);
}

/// Warms the PDF fonts at startup so the FIRST print isn't blocked by a slow
/// font fetch. On mobile the OS share sheet must open within the user's tap
/// gesture; a slow first-time font download breaks that (the tap appears to do
/// nothing, and only the second tap works). Call once, fire-and-forget.
Future<void> preloadPdfFonts() async {
  try {
    await PdfGoogleFonts.notoSansRegular();
    await PdfGoogleFonts.notoSansBold();
  } catch (_) {
    // Best-effort; buildPdfService will fetch again if needed.
  }
}

/// Delivers the PDF appropriately for the platform:
/// - Mobile (Android/iOS, incl. mobile browsers): the native share sheet, which
///   offers Print, Save to Files, and send. `layoutPdf`'s print dialog is
///   unreliable on mobile, so we share instead.
/// - Desktop / desktop web: the print dialog.
Future<void> printBytes(Uint8List bytes, {String name = 'greenchain.pdf'}) async {
  final isMobile = defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
  if (isMobile) {
    await Printing.sharePdf(bytes: bytes, filename: name);
  } else {
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: name);
  }
}

/// Runs a build+print action, surfacing any failure as a SnackBar instead of
/// an uncaught error (font fetch, print dialog, etc.).
Future<void> runPrint(
  BuildContext context,
  Future<Uint8List> Function(ShoppingPdfService svc, AppLocalizations l10n) build, {
  String name = 'greenchain.pdf',
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  try {
    final svc = await buildPdfService();
    final bytes = await build(svc, l10n);
    await printBytes(bytes, name: name);
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.printFailed(e.toString()))));
  }
}
