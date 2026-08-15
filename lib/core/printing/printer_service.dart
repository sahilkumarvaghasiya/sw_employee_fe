import 'barcode_label_data.dart';
import 'barcode_label_layout.dart';

abstract class PrinterService {
  Future<void> printBarcodeLabel({
    required BarcodeLabelData data,
    BarcodeLabelLayout layout = BarcodeLabelLayout.label50x38,
    String jobName = 'barcode_label',
  });
}
