import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

const MethodChannel _downloadsChannel = MethodChannel(
  'com.example.sw_billing_employee_fe/downloads',
);

Future<String> saveBarcodePngImpl({
  required Uint8List bytes,
  required String fileName,
}) async {
  // Android: save to the user's public Downloads folder (visible in Files app).
  if (Platform.isAndroid) {
    try {
      final location = await _downloadsChannel.invokeMethod<String>(
        'saveToDownloads',
        <String, Object?>{'fileName': fileName, 'bytes': bytes},
      );
      return location == null
          ? 'Saved to Downloads/$fileName'
          : 'Saved to Downloads ($location)';
    } catch (_) {
      // Fallback below.
    }
  }

  Directory? baseDir;
  baseDir ??= await getDownloadsDirectory();
  baseDir ??= await getApplicationDocumentsDirectory();

  final sep = Platform.pathSeparator;
  final path = '${baseDir.path}$sep$fileName';
  final file = File(path);
  await file.writeAsBytes(bytes, flush: true);
  return 'Saved to $path';
}
