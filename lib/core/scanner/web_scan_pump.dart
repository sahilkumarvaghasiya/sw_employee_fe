import 'dart:ui';

import 'web_scan_pump_stub.dart'
    if (dart.library.js_interop) 'web_scan_pump_web.dart' as impl;

/// Compile-time kill switch for the web decode pump.
const bool _webScanPumpEnabled = true;

/// Whether to layer our decoder over the plugin's preview.
///
/// Appending `?legacyscan=1` to the app URL falls back to `mobile_scanner`'s
/// built-in zxing-js decoder, so a bad field report can be rolled back by
/// sending users a link — no rebuild or redeploy needed.
bool get kUseWebScanPump => _webScanPumpEnabled && !impl.legacyScanRequested();

/// A stronger barcode decoder layered on top of the `mobile_scanner` preview.
///
/// `mobile_scanner` keeps owning the camera, the preview widget, permissions
/// and error states — this only reads frames from the `<video>` element it
/// already created and decodes them properly:
///
///  * **Native `BarcodeDetector`** where the browser has it (Chrome/Edge on
///    Android). On Android that is backed by Play Services ML Kit, i.e. the
///    same engine as the native app build.
///  * **ZXing-C++ in WebAssembly**, in a worker, everywhere else — notably iOS
///    Safari. Far stronger than the hand-ported zxing-js the plugin uses, and
///    with `tryHarder` actually switched on.
///
/// Frames are cropped to the scan window before decoding, which both raises the
/// pixels-per-bar the decoder sees and keeps the size chart, price and address
/// text on a hang tag from competing with the real barcode.
///
/// Every method is a no-op off the web.
abstract class WebScanPump {
  factory WebScanPump({
    required void Function(String value) onBarcode,
  }) = impl.WebScanPumpImpl;

  /// Begins polling for the preview element, then decoding once it appears.
  void start();

  /// Reports the scan window in widget coordinates, so frames can be cropped to
  /// it. The preview is laid out with [BoxFit.cover], which the implementation
  /// accounts for when mapping the window into video pixels.
  void setScanWindow(Rect scanWindow, Size previewSize);

  /// Pauses decoding without tearing down the worker.
  void setEnabled(bool enabled);

  void dispose();
}
