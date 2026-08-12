import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui';

import 'package:web/web.dart' as web;

import 'web_camera_tuning.dart';
import 'web_video_element.dart';

/// Target capture size. 1080p cropped to the scan window already puts ~8-10 px
/// on each bar of a hang-tag EAN-13; asking for more mostly costs decode time.
const int _idealWidth = 1920;
const int _idealHeight = 1080;

/// Below this a small hang-tag barcode cannot survive the frame, so we retry
/// once with a hard minimum before accepting what the browser gave us.
const int _minAcceptableWidth = 1280;

const Duration _pollInterval = Duration(milliseconds: 150);

web.MediaStreamTrack? _track;
double? _zoom;
bool _torchOn = false;
bool _applying = false;
bool _reapplyRequested = false;

Future<WebCameraTuning> tuneWebCameraForScanning({
  Duration timeout = const Duration(seconds: 6),
}) async {
  final track = await _awaitLiveVideoTrack(timeout);
  if (track == null) return const WebCameraTuning.unavailable();

  _track = track;
  _zoom = null;
  _torchOn = false;

  final capabilities = _capabilities(track);
  final zoomRange = _readRange(capabilities, 'zoom');

  await _reapply();

  var resolution = _settledResolution(track);

  // Chrome and Safari both honour `ideal`, but some WebViews quietly stay on
  // their 640x480 default. One retry with `min` shakes those loose.
  if (resolution.width < _minAcceptableWidth) {
    final retried = await _apply(
      track,
      _buildConstraints(capabilities, minWidth: _minAcceptableWidth),
    );
    if (retried) {
      resolution = _settledResolution(track);
    }
  }

  return WebCameraTuning(
    applied: true,
    resolution: resolution,
    zoomMin: zoomRange?.min,
    zoomMax: zoomRange?.max,
    zoomStep: zoomRange?.step,
    supportsTorch: _readFlag(capabilities, 'torch'),
    supportsContinuousFocus: _supportsContinuousFocus(capabilities),
  );
}

Future<void> setWebCameraZoom(double zoom) async {
  final track = _resolveTrack();
  if (track == null) return;

  final range = _readRange(_capabilities(track), 'zoom');
  if (range == null) return;

  _zoom = zoom.clamp(range.min, range.max);
  await _reapply();
}

Future<void> setWebCameraTorch(bool enabled) async {
  if (_resolveTrack() == null) return;

  _torchOn = enabled;
  await _reapply();
}

void releaseWebCameraTuner() {
  _track = null;
  _zoom = null;
  _torchOn = false;
}

/// Returns the cached track while it is still live, otherwise re-resolves it.
///
/// Two scan screens can be alive at once (a form pushed over the billing
/// screen), and disposing the top one clears the shared cache. Re-resolving
/// keeps the screen underneath working instead of silently dropping its
/// zoom and torch controls.
web.MediaStreamTrack? _resolveTrack() {
  final cached = _track;
  if (cached != null && cached.readyState == 'live') return cached;

  return _track = findLiveScannerTrack();
}

/// `applyConstraints` replaces the whole constraint set rather than merging, so
/// every change has to re-send resolution, focus, zoom and torch together.
/// Slider drags are coalesced: a request that arrives mid-flight sets a dirty
/// flag instead of queueing another round-trip.
Future<void> _reapply() async {
  if (_applying) {
    _reapplyRequested = true;
    return;
  }

  _applying = true;
  try {
    do {
      _reapplyRequested = false;
      final track = _resolveTrack();
      if (track == null) return;
      await _apply(track, _buildConstraints(_capabilities(track)));
    } while (_reapplyRequested);
  } finally {
    _applying = false;
  }
}

JSObject _buildConstraints(JSObject? capabilities, {int? minWidth}) {
  final width = JSObject()..setProperty('ideal'.toJS, _idealWidth.toJS);
  final height = JSObject()..setProperty('ideal'.toJS, _idealHeight.toJS);
  if (minWidth != null) {
    width.setProperty('min'.toJS, minWidth.toJS);
    height.setProperty('min'.toJS, ((minWidth * 9) ~/ 16).toJS);
  }

  // Advanced constraints are best-effort by spec: a browser that cannot satisfy
  // one skips it instead of failing the whole call.
  final advanced = <JSObject>[
    // Stop the browser downscaling a high-res sensor back to its default.
    JSObject()..setProperty('resizeMode'.toJS, 'none'.toJS),
    if (_supportsContinuousFocus(capabilities))
      JSObject()..setProperty('focusMode'.toJS, 'continuous'.toJS),
    if (_zoom != null) JSObject()..setProperty('zoom'.toJS, _zoom!.toJS),
    if (_readFlag(capabilities, 'torch'))
      JSObject()..setProperty('torch'.toJS, _torchOn.toJS),
  ];

  return JSObject()
    ..setProperty('width'.toJS, width)
    ..setProperty('height'.toJS, height)
    ..setProperty('advanced'.toJS, advanced.toJS);
}

Future<bool> _apply(web.MediaStreamTrack track, JSObject constraints) async {
  try {
    final promise = (track as JSObject).callMethod<JSPromise<JSAny?>>(
      'applyConstraints'.toJS,
      constraints,
    );
    await promise.toDart;
    return true;
  } on Object {
    // OverconstrainedError / NotSupportedError: keep whatever stream the
    // browser already gave us rather than killing the preview.
    return false;
  }
}

Future<web.MediaStreamTrack?> _awaitLiveVideoTrack(Duration timeout) async {
  // The plugin creates its <video> element asynchronously after start(), so
  // poll rather than assume it is already attached.
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final track = findLiveScannerTrack();
    if (track != null) return track;
    await Future<void>.delayed(_pollInterval);
  }
  return findLiveScannerTrack();
}

JSObject? _capabilities(web.MediaStreamTrack track) {
  final object = track as JSObject;
  // Safari shipped getCapabilities late; older versions have no such method.
  if (!object.has('getCapabilities')) return null;

  try {
    return object.callMethod<JSObject?>('getCapabilities'.toJS);
  } on Object {
    return null;
  }
}

Size _settledResolution(web.MediaStreamTrack track) {
  try {
    final settings = (track as JSObject).callMethod<JSObject?>(
      'getSettings'.toJS,
    );
    if (settings == null) return Size.zero;

    return Size(
      _readNumber(settings, 'width') ?? 0,
      _readNumber(settings, 'height') ?? 0,
    );
  } on Object {
    return Size.zero;
  }
}

bool _supportsContinuousFocus(JSObject? capabilities) {
  return _readStringList(capabilities, 'focusMode').contains('continuous');
}

({double min, double max, double step})? _readRange(
  JSObject? capabilities,
  String key,
) {
  if (capabilities == null || !capabilities.has(key)) return null;

  final raw = capabilities.getProperty<JSAny?>(key.toJS);
  if (raw == null || !raw.isA<JSObject>()) return null;

  final range = raw as JSObject;
  final min = _readNumber(range, 'min');
  final max = _readNumber(range, 'max');
  if (min == null || max == null || max <= min) return null;

  final step = _readNumber(range, 'step');
  return (
    min: min,
    max: max,
    step: step != null && step > 0 ? step : (max - min) / 20,
  );
}

bool _readFlag(JSObject? capabilities, String key) {
  if (capabilities == null || !capabilities.has(key)) return false;

  final raw = capabilities.getProperty<JSAny?>(key.toJS);
  if (raw == null) return false;

  // Chrome reports torch as a bare boolean; some builds use [false, true].
  if (raw.isA<JSBoolean>()) return (raw as JSBoolean).toDart;
  if (raw.isA<JSArray<JSAny?>>()) {
    return (raw as JSArray<JSAny?>).toDart.any(
      (value) =>
          value != null && value.isA<JSBoolean>() && (value as JSBoolean).toDart,
    );
  }
  return false;
}

List<String> _readStringList(JSObject? capabilities, String key) {
  if (capabilities == null || !capabilities.has(key)) return const [];

  final raw = capabilities.getProperty<JSAny?>(key.toJS);
  if (raw == null || !raw.isA<JSArray<JSAny?>>()) return const [];

  return [
    for (final value in (raw as JSArray<JSAny?>).toDart)
      if (value != null && value.isA<JSString>()) (value as JSString).toDart,
  ];
}

double? _readNumber(JSObject object, String key) {
  if (!object.has(key)) return null;

  final raw = object.getProperty<JSAny?>(key.toJS);
  if (raw == null || !raw.isA<JSNumber>()) return null;

  return (raw as JSNumber).toDartDouble;
}
