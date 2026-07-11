// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:typed_data';

import 'barcode_frame_decoder.dart';

/// Reads digits printed near a barcode using image heuristics.
Future<String?> readPrintedBarcodeNumber(Uint8List imageBytes) async {
  const decoder = BarcodeFrameDecoder();
  final result = await decoder.decodePrintedNumberNearBarcode(imageBytes);
  return result?.value;
}
