import 'dart:typed_data';

import 'barcode_label_text_reader_stub.dart'
    if (dart.library.html) 'barcode_label_text_reader_web.dart' as impl;

/// Attempts to read a barcode number printed near the bars on a label.
Future<String?> readPrintedBarcodeNumber(Uint8List imageBytes) {
  return impl.readPrintedBarcodeNumber(imageBytes);
}
