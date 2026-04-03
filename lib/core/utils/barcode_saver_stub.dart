import 'dart:typed_data';

Future<String> saveBarcodePngImpl({
  required Uint8List bytes,
  required String fileName,
}) {
  throw UnsupportedError('Saving barcode is not supported on this platform');
}
