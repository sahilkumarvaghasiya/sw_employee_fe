import 'web_camera_tuning.dart';

/// Native builds keep `mobile_scanner` + ML Kit, which already opens the camera
/// at a sensible resolution. Nothing to tune here.
Future<WebCameraTuning> tuneWebCameraForScanning({
  Duration timeout = const Duration(seconds: 6),
}) async {
  return const WebCameraTuning.unavailable();
}

Future<void> setWebCameraZoom(double zoom) async {}

Future<void> setWebCameraTorch(bool enabled) async {}

void releaseWebCameraTuner() {}
