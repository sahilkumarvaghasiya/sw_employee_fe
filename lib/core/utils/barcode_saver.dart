import 'dart:typed_data';

import 'barcode_saver_stub.dart'
    if (dart.library.html) 'barcode_saver_web.dart'
    if (dart.library.io) 'barcode_saver_io.dart';

Future<String> saveBarcodePng({
  required Uint8List bytes,
  required String fileName,
}) {
  return saveBarcodePngImpl(bytes: bytes, fileName: fileName);
}
