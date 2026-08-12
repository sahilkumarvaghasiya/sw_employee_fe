import 'dart:ui';

import 'web_scan_pump.dart';

bool legacyScanRequested() => false;

/// Native builds decode with ML Kit through `mobile_scanner`, so there is
/// nothing to layer on top.
class WebScanPumpImpl implements WebScanPump {
  WebScanPumpImpl({required void Function(String value) onBarcode});

  @override
  void start() {}

  @override
  void setScanWindow(Rect scanWindow, Size previewSize) {}

  @override
  void setEnabled(bool enabled) {}

  @override
  void dispose() {}
}
