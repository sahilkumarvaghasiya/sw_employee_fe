import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Die-cut label stock the app can print on.
///
/// Every size is 50mm wide or narrower so a single 2-inch thermal transfer
/// printer covers all of them — a shop buys one machine whichever roll it
/// stocks.
enum BarcodeLabelSize {
  /// Default. Fits name, size/colour, price, barcode and digits comfortably.
  mm50x38,

  /// Compact roll. One line short, so size/colour merges onto the name line.
  mm50x25,

  /// Narrower roll. Barcode is tighter but still well above scannable minimum.
  mm40x30,
}

extension BarcodeLabelSizeInfo on BarcodeLabelSize {
  /// Value persisted in preferences. Kept stable — do not rename.
  String get storageKey {
    switch (this) {
      case BarcodeLabelSize.mm50x38:
        return '50x38';
      case BarcodeLabelSize.mm50x25:
        return '50x25';
      case BarcodeLabelSize.mm40x30:
        return '40x30';
    }
  }

  String get label {
    switch (this) {
      case BarcodeLabelSize.mm50x38:
        return '50 × 38 mm';
      case BarcodeLabelSize.mm50x25:
        return '50 × 25 mm';
      case BarcodeLabelSize.mm40x30:
        return '40 × 30 mm';
    }
  }

  String get shortLabel {
    switch (this) {
      case BarcodeLabelSize.mm50x38:
        return '50×38';
      case BarcodeLabelSize.mm50x25:
        return '50×25';
      case BarcodeLabelSize.mm40x30:
        return '40×30';
    }
  }

  static BarcodeLabelSize fromStorageKey(String? key) {
    for (final size in BarcodeLabelSize.values) {
      if (size.storageKey == key) return size;
    }
    return BarcodeLabelSize.mm50x38;
  }
}

/// Everything the PDF builder and the on-screen preview need to draw one
/// label at a given stock size.
///
/// Heights are the constraint, not widths: a 9-digit Code128 needs ~90
/// modules, which is 0.39mm per module even on the 40mm roll — comfortably
/// above the ~0.25mm scanning minimum. The vertical budget is what forces
/// [mergeSubtitleIntoName] on the 25mm-tall stock.
class BarcodeLabelLayout {
  const BarcodeLabelLayout({
    this.size = BarcodeLabelSize.mm50x38,
    this.pageFormat = const PdfPageFormat(
      50 * PdfPageFormat.mm,
      38 * PdfPageFormat.mm,
      marginAll: 0,
    ),
    this.padding = const pw.EdgeInsets.all(3),
    this.barcodeHeight = 26,
    this.nameFontSize = 9,
    this.nameMaxLines = 2,
    this.subtitleFontSize = 6,
    this.maxSubtitleLines = 2,
    this.priceFontSize = 8.5,
    this.codeFontSize = 7,
    this.mergeSubtitleIntoName = false,
  });

  /// 50 × 38 mm — the recommended default.
  static const BarcodeLabelLayout label50x38 = BarcodeLabelLayout();

  /// 50 × 25 mm — one line of vertical budget short, so size/colour is folded
  /// into the name line instead of being dropped.
  static const BarcodeLabelLayout label50x25 = BarcodeLabelLayout(
    size: BarcodeLabelSize.mm50x25,
    pageFormat: PdfPageFormat(
      50 * PdfPageFormat.mm,
      25 * PdfPageFormat.mm,
      marginAll: 0,
    ),
    padding: pw.EdgeInsets.all(3),
    barcodeHeight: 24,
    nameFontSize: 8,
    nameMaxLines: 1,
    subtitleFontSize: 6,
    maxSubtitleLines: 0,
    priceFontSize: 8,
    codeFontSize: 6.5,
    mergeSubtitleIntoName: true,
  );

  /// 40 × 30 mm — all lines still fit, everything scaled down a step.
  static const BarcodeLabelLayout label40x30 = BarcodeLabelLayout(
    size: BarcodeLabelSize.mm40x30,
    pageFormat: PdfPageFormat(
      40 * PdfPageFormat.mm,
      30 * PdfPageFormat.mm,
      marginAll: 0,
    ),
    padding: pw.EdgeInsets.all(3),
    barcodeHeight: 22,
    nameFontSize: 8.5,
    nameMaxLines: 1,
    subtitleFontSize: 6,
    priceFontSize: 8,
    codeFontSize: 6.5,
  );

  static BarcodeLabelLayout forSize(BarcodeLabelSize size) {
    switch (size) {
      case BarcodeLabelSize.mm50x38:
        return label50x38;
      case BarcodeLabelSize.mm50x25:
        return label50x25;
      case BarcodeLabelSize.mm40x30:
        return label40x30;
    }
  }

  final BarcodeLabelSize size;
  final PdfPageFormat pageFormat;
  final pw.EdgeInsets padding;
  final double barcodeHeight;
  final double nameFontSize;
  final int nameMaxLines;
  final double subtitleFontSize;

  /// Hard cap on subtitle lines. The label is a fixed height, so an extra
  /// line would push the barcode off the bottom instead of growing the page.
  final int maxSubtitleLines;

  final double priceFontSize;
  final double codeFontSize;

  /// When true the subtitle lines are appended to the name line
  /// (`T-SHIRT · M · Red`) instead of being drawn separately.
  final bool mergeSubtitleIntoName;
}
