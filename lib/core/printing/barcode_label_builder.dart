import 'package:barcode/barcode.dart';
import 'package:pdf/widgets.dart' as pw;

import 'barcode_label_data.dart';
import 'barcode_label_layout.dart';

class BarcodeLabelBuilder {
  const BarcodeLabelBuilder();

  pw.Document buildDocument({
    required BarcodeLabelData data,
    BarcodeLabelLayout layout = BarcodeLabelLayout.label50x38,
  }) {
    final document = pw.Document();
    final subtitleLines = layout.mergeSubtitleIntoName
        ? const <String>[]
        : data.cappedSubtitleLines(layout.maxSubtitleLines);
    final name = layout.mergeSubtitleIntoName ? data.mergedName : data.itemName;

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
                      name,
                      maxLines: layout.nameMaxLines,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: layout.nameFontSize,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (subtitleLines.isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      ...subtitleLines.map(
                        (line) => pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 1),
                          child: pw.Text(
                            line,
                            textAlign: pw.TextAlign.center,
                            maxLines: 1,
                            style: pw.TextStyle(
                              fontSize: layout.subtitleFontSize,
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (data.hasPrice) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Price: ${data.trimmedPrice}',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontSize: layout.priceFontSize,
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
                      style: pw.TextStyle(fontSize: layout.codeFontSize),
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
