import 'package:printing/printing.dart';

import 'barcode_label_builder.dart';
import 'barcode_label_data.dart';
import 'barcode_label_layout.dart';
import 'printer_service.dart';

class PdfPrinterService implements PrinterService {
  PdfPrinterService({BarcodeLabelBuilder? builder})
    : _builder = builder ?? const BarcodeLabelBuilder();

  final BarcodeLabelBuilder _builder;

  @override
  Future<void> printBarcodeLabel({
    required BarcodeLabelData data,
    BarcodeLabelLayout layout = const BarcodeLabelLayout(),
    String jobName = 'barcode_label',
  }) async {
    final pdf = _builder.buildDocument(data: data, layout: layout);

    await Printing.layoutPdf(
      name: jobName,
      onLayout: (format) async => pdf.save(),
    );
  }
}
