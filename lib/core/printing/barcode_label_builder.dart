import 'package:barcode/barcode.dart';
import 'package:pdf/widgets.dart' as pw;

import 'barcode_label_data.dart';
import 'barcode_label_layout.dart';

class BarcodeLabelBuilder {
  const BarcodeLabelBuilder();

  pw.Document buildDocument({
    required BarcodeLabelData data,
    BarcodeLabelLayout layout = const BarcodeLabelLayout(),
  }) {
    final document = pw.Document();

    document.addPage(
      pw.Page(
        pageFormat: layout.pageFormat,
        margin: pw.EdgeInsets.zero,
        build: (context) {
          return pw.Container(
            padding: layout.padding,
            width: double.infinity,
            height: double.infinity,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.Text(
                      data.itemName,
                      maxLines: 2,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (data.subtitleLines.isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      ...data.subtitleLines.map(
                        (line) => pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 1),
                          child: pw.Text(
                            line,
                            textAlign: pw.TextAlign.center,
                            maxLines: 1,
                            style: const pw.TextStyle(fontSize: 7),
                          ),
                        ),
                      ),
                    ],
                    if (data.price != null &&
                        data.price!.trim().isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Price: ${data.price}',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.BarcodeWidget(
                      barcode: Barcode.code128(),
                      data: data.barcode,
                      drawText: false,
                      height: layout.barcodeHeight,
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      data.barcode,
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    return document;
  }
}
