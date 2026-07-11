import 'dart:typed_data';

import 'barcode_frame_decoder.dart';

/// Reads digits or alphanumeric text printed near a barcode using image heuristics.
Future<String?> readPrintedBarcodeNumber(
  Uint8List imageBytes, {
  bool live = true,
}) async {
  const decoder = BarcodeFrameDecoder();
  final result = await decoder.decodePrintedNumberNearBarcode(
    imageBytes,
    live: live,
  );
  return result?.value;
}
