import 'package:flutter/foundation.dart';

import 'web_camera_tuner_stub.dart'
    if (dart.library.js_interop) 'web_camera_tuner_web.dart' as impl;
import 'web_camera_tuning.dart';

export 'web_camera_tuning.dart';

/// Forces a barcode-readable camera stream on Flutter web.
///
/// `mobile_scanner`'s web plugin opens the camera with only a `facingMode`
/// constraint, so every browser hands it its 640x480 default. An EAN-13 is 95
/// modules wide; on a small cloth hang-tag that leaves ~1.5-2 px per bar, which
/// is below what any decoder can read. That — not the decoder — is why scanning
/// fails on most Androids and only some iPhones.
///
/// This re-applies proper constraints to the live track after the plugin has
/// started it: 1080p, continuous autofocus, plus zoom and torch where the
/// browser exposes them. Zoom matters as much as resolution: it lets the user
/// magnify a small barcode while staying outside the lens's minimum focus
/// distance, instead of moving closer until the image blurs.
///
/// No-op off the web.
Future<WebCameraTuning> tuneWebCameraForScanning({
  Duration timeout = const Duration(seconds: 6),
}) async {
  final tuning = await impl.tuneWebCameraForScanning(timeout: timeout);

  if (kDebugMode && tuning.applied) {
    // The one number that proves the fix landed: untuned this reads 640x480.
    debugPrint(
      '[scanner] camera ${tuning.resolution.width.toInt()}'
      'x${tuning.resolution.height.toInt()} '
      'zoom=${tuning.supportsZoom} torch=${tuning.supportsTorch} '
      'continuousFocus=${tuning.supportsContinuousFocus}',
    );
  }

  return tuning;
}

/// Applies a hardware zoom factor, clamped to the track's reported range.
Future<void> setWebCameraZoom(double zoom) => impl.setWebCameraZoom(zoom);

/// Toggles the camera torch. Useful on glossy or poly-bagged tags.
Future<void> setWebCameraTorch(bool enabled) => impl.setWebCameraTorch(enabled);

/// Drops the cached track reference when a scan screen closes.
void releaseWebCameraTuner() => impl.releaseWebCameraTuner();
