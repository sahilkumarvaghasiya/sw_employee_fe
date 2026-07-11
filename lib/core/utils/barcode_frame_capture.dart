import 'dart:typed_data';
import 'dart:ui';

import 'barcode_frame_capture_stub.dart'
    if (dart.library.html) 'barcode_frame_capture_web.dart' as impl;

/// Captures a still frame from the active camera preview, when supported.
Future<Uint8List?> captureCameraPreviewFrame({Rect? cropRect}) {
  return impl.captureCameraPreviewFrame(cropRect: cropRect);
}
