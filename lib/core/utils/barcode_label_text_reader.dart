import 'dart:typed_data';

import 'barcode_label_text_reader_impl.dart' as impl;

/// Attempts to read a barcode number printed near the bars on a label.
Future<String?> readPrintedBarcodeNumber(
  Uint8List imageBytes, {
  bool live = true,
}) {
  return impl.readPrintedBarcodeNumber(imageBytes, live: live);
}
