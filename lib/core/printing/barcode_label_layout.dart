import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class BarcodeLabelLayout {
  const BarcodeLabelLayout({
    this.pageFormat = const PdfPageFormat(
      58 * PdfPageFormat.mm,
      40 * PdfPageFormat.mm,
      marginAll: 0,
    ),
    this.padding = const pw.EdgeInsets.all(4),
    this.barcodeHeight = 18,
  });

  final PdfPageFormat pageFormat;
  final pw.EdgeInsets padding;
  final double barcodeHeight;
}
