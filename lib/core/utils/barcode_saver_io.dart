import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<String> saveBarcodePngImpl({
  required Uint8List bytes,
  required String fileName,
}) async {
  Directory? baseDir;

  if (Platform.isAndroid) {
    baseDir = await getExternalStorageDirectory();
  }

  baseDir ??= await getDownloadsDirectory();
  baseDir ??= await getApplicationDocumentsDirectory();

  final sep = Platform.pathSeparator;
  final path = '${baseDir.path}$sep$fileName';

  final file = File(path);
  await file.writeAsBytes(bytes, flush: true);

  return 'Saved to $path';
}
