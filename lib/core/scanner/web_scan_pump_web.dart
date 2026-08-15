import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;
import 'dart:ui';

import 'package:web/web.dart' as web;

import '../utils/web_video_element.dart';
import 'web_scan_pump.dart';

/// How often we grab a frame. ~11 fps leaves the browser plenty of room to keep
/// the preview smooth while still feeling instant to a user holding a tag.
const Duration _pumpInterval = Duration(milliseconds: 90);

/// Horizontal slack around the scan window. 1D symbologies need a quiet zone
/// past the last bar, so a crop flush with the barcode decodes as nothing.
const double _cropPaddingX = 0.12;

/// Vertical slack. Deliberately generous: a barcode of length L held at angle
/// θ spans L·sin θ vertically, and hang-tag barcodes are long and only a
/// centimetre tall, so a tilted one leaves a short crop almost immediately.
const double _cropPaddingY = 0.45;

/// Floor on crop height as a fraction of its width. Without this the crop stays
/// a letterbox and clips the ends off any tilted barcode — which is the whole
/// reason tilted tags failed.
const double _minCropAspect = 0.55;

/// Hard ceiling on the canvas we build, so a pathological layout cannot hand
/// the decoder an enormous image.
const int _maxCanvasSide = 3000;

/// BarcodeDetector's names for the 1D symbologies in
/// `BarcodeScanProfile.stockEntry1dFormats`. 2D formats are deliberately
/// excluded: hang tags often carry one next to the product barcode.
const List<String> _detectorFormats = [
  'code_128',
  'code_39',
  'code_93',
  'codabar',
  'ean_13',
  'ean_8',
  'itf',
  'upc_a',
  'upc_e',
];

/// Production rollback hatch: `?legacyscan=1` reverts to the plugin's own
/// zxing-js decoder without a redeploy.
bool legacyScanRequested() {
  try {
    return web.window.location.search.contains('legacyscan=1');
  } on Object {
    return false;
  }
}

class WebScanPumpImpl implements WebScanPump {
  WebScanPumpImpl({required this.onBarcode});

  final void Function(String value) onBarcode;

  Timer? _timer;
  bool _busy = false;
  bool _enabled = true;
  bool _disposed = false;
  int _tickCount = 0;
  int _ladderIndex = 0;
  int? _preferredRotation;

  Rect? _scanWindow;
  Size _previewSize = Size.zero;

  web.HTMLCanvasElement? _canvas;
  web.CanvasRenderingContext2D? _context;

  _Decoder? _decoder;
  Future<_Decoder?>? _decoderSetup;

  @override
  void start() {
    if (_disposed || _timer != null) return;

    _decoderSetup = _createDecoder();
    _timer = Timer.periodic(_pumpInterval, (_) => unawaited(_tick()));
  }

  @override
  void setScanWindow(Rect scanWindow, Size previewSize) {
    _scanWindow = scanWindow;
    _previewSize = previewSize;
  }

  @override
  void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    _decoder?.dispose();
    _decoder = null;
    _canvas = null;
    _context = null;
  }

  Future<void> _tick() async {
    if (_disposed || !_enabled || _busy) return;

    _busy = true;
    try {
      final decoder = _decoder ??= await (_decoderSetup ??= _createDecoder());
      if (decoder == null || _disposed) return;

      final rotation = _nextRotation(decoder.rotationLadder);

      // The full-frame sweep exists to catch a barcode held outside the green
      // box — an aiming problem, not an angle one — so only spend ticks on it
      // while we are already scanning upright.
      final fullFrame = rotation == 0 && _tickCount % 4 == 3;
      _tickCount++;

      final canvas = _captureFrame(
        fullFrame: fullFrame,
        rotationDegrees: rotation,
        maxWidth: decoder.maxSourceWidth,
      );
      if (canvas == null || _disposed) return;

      final value = await decoder.decode(canvas);
      if (value == null || value.isEmpty || _disposed || !_enabled) return;

      _preferredRotation = rotation;
      onBarcode(value);
    } on Object {
      // Frames without a barcode are the common case, and a transient canvas or
      // worker failure must not kill the pump.
    } finally {
      _busy = false;
    }
  }

  /// Angle to un-rotate the frame by before decoding.
  ///
  /// ZXing scans axis-aligned lines. `tryRotate` buys it 90°, and a 1D symbol
  /// reads the same reversed so 180° is free — but a tag held anywhere between
  /// roughly 15° and 75° decodes as nothing however sharp the image is. Sweeping
  /// a few angles closes that gap, verified across 0-180°.
  ///
  /// The angle that last worked is retried on alternate ticks, so a steady hand
  /// gets its second confirming read straight away instead of waiting for the
  /// sweep to come round again.
  int _nextRotation(List<int> ladder) {
    if (ladder.length <= 1) return 0;

    final preferred = _preferredRotation;
    if (preferred != null && _tickCount.isEven) return preferred;

    final angle = ladder[_ladderIndex % ladder.length];
    _ladderIndex++;
    return angle;
  }

  /// Squares up a crop around its centre.
  ///
  /// Rotating a letterbox crop about its centre swings the ends of a long
  /// barcode straight out of frame, which would defeat the whole point.
  Rect _squareAround(Rect crop, Size videoSize) {
    final side = math.min(
      math.max(crop.width, crop.height),
      math.min(videoSize.width, videoSize.height),
    );
    final square = Rect.fromCenter(
      center: crop.center,
      width: side,
      height: side,
    );

    // Slide it back inside the frame rather than shrinking it, so the side
    // length — and with it the resolution — is preserved.
    var dx = 0.0;
    var dy = 0.0;
    if (square.left < 0) dx = -square.left;
    if (square.right > videoSize.width) dx = videoSize.width - square.right;
    if (square.top < 0) dy = -square.top;
    if (square.bottom > videoSize.height) dy = videoSize.height - square.bottom;

    return square.shift(Offset(dx, dy));
  }

  /// Draws the scan window region of the preview into a reusable canvas,
  /// magnifying it when the crop is small.
  ///
  /// Cropping is what makes the green frame meaningful: it raises the pixels
  /// per bar the decoder sees and removes the size chart, price and address
  /// text from the image entirely.
  web.HTMLCanvasElement? _captureFrame({
    required bool fullFrame,
    required int rotationDegrees,
    required int maxWidth,
  }) {
    final video = findLiveScannerVideo();
    if (video == null) return null;

    final videoWidth = video.videoWidth;
    final videoHeight = video.videoHeight;
    if (videoWidth <= 0 || videoHeight <= 0) return null;

    final videoSize = Size(videoWidth.toDouble(), videoHeight.toDouble());
    var crop = fullFrame
        ? Rect.fromLTWH(0, 0, videoSize.width, videoSize.height)
        : _cropInVideoPixels(videoSize);

    if (rotationDegrees != 0) {
      crop = _squareAround(crop, videoSize);
    }

    // Magnify the crop, but never upscale a full frame — that spends decode
    // time on pixels carrying no extra detail.
    final fit = maxWidth / math.max(crop.width, 1);
    final scale = fullFrame ? math.min(1.0, fit) : fit.clamp(1.0, 4.0);

    final targetWidth = (crop.width * scale).round().clamp(16, _maxCanvasSide);
    final targetHeight = (crop.height * scale).round().clamp(16, _maxCanvasSide);

    final canvas = _ensureCanvas(targetWidth, targetHeight);
    final context = _context;
    if (context == null) return null;

    if (rotationDegrees == 0) {
      context.drawImage(
        video,
        crop.left,
        crop.top,
        crop.width,
        crop.height,
        0,
        0,
        targetWidth,
        targetHeight,
      );
      return canvas;
    }

    context.save();
    // Corners left bare by the rotation must read as quiet zone, not as bars.
    context.fillStyle = '#ffffff'.toJS;
    context.fillRect(0, 0, targetWidth.toDouble(), targetHeight.toDouble());
    context.translate(targetWidth / 2, targetHeight / 2);
    context.rotate(-rotationDegrees * math.pi / 180);
    context.drawImage(
      video,
      crop.left,
      crop.top,
      crop.width,
      crop.height,
      -targetWidth / 2,
      -targetHeight / 2,
      targetWidth,
      targetHeight,
    );
    context.restore();

    return canvas;
  }

  /// Maps the scan window from widget space into video pixels.
  ///
  /// The preview is rendered with [BoxFit.cover], so the video is scaled up
  /// until it covers the widget and the overflow is clipped — the crop has to
  /// undo exactly that transform.
  Rect _cropInVideoPixels(Size videoSize) {
    final full = Rect.fromLTWH(0, 0, videoSize.width, videoSize.height);

    final window = _scanWindow;
    final preview = _previewSize;
    if (window == null || preview.width <= 0 || preview.height <= 0) {
      return full;
    }

    final scale = math.max(
      preview.width / videoSize.width,
      preview.height / videoSize.height,
    );
    if (scale <= 0) return full;

    final offsetX = (preview.width - videoSize.width * scale) / 2;
    final offsetY = (preview.height - videoSize.height * scale) / 2;

    final raw = Rect.fromLTRB(
      (window.left - offsetX) / scale,
      (window.top - offsetY) / scale,
      (window.right - offsetX) / scale,
      (window.bottom - offsetY) / scale,
    );

    // Pad each axis by a fraction of *that* axis. Inflating by the longest side
    // (as this used to) blows a wide, short window up to the whole frame and
    // silently cancels the crop.
    final padded = Rect.fromCenter(
      center: raw.center,
      width: raw.width * (1 + 2 * _cropPaddingX),
      height: math.max(
        raw.height * (1 + 2 * _cropPaddingY),
        raw.width * _minCropAspect,
      ),
    );
    final clamped = padded.intersect(full);

    // A degenerate window (mid-layout) must not produce an empty crop.
    if (clamped.width < 16 || clamped.height < 16) return full;
    return clamped;
  }

  web.HTMLCanvasElement _ensureCanvas(int width, int height) {
    final canvas = _canvas ??= web.HTMLCanvasElement();
    if (canvas.width != width || canvas.height != height) {
      canvas.width = width;
      canvas.height = height;
      _context = null;
    }

    _context ??= canvas.getContext(
      '2d',
      // Frames are read back immediately, so keep them in system memory.
      (JSObject()..setProperty('willReadFrequently'.toJS, true.toJS)),
    ) as web.CanvasRenderingContext2D?;

    return canvas;
  }

  /// Prefers the browser's native detector, falling back to ZXing-C++ in a
  /// worker. On Android Chrome the native path is backed by Play Services ML
  /// Kit — the same engine as the native app build.
  Future<_Decoder?> _createDecoder() async {
    final native = await _BarcodeDetectorDecoder.tryCreate();
    if (native != null) return native;

    return _WasmWorkerDecoder.tryCreate();
  }
}

abstract class _Decoder {
  /// Widest source image worth building for this decoder. More pixels per bar
  /// is what rescues tilted and small barcodes, but the two tiers pay very
  /// different prices for it.
  int get maxSourceWidth;

  /// Angles to sweep looking for a tilted barcode. A single `[0]` means the
  /// decoder finds rotated symbols by itself and sweeping would only waste
  /// ticks.
  List<int> get rotationLadder;

  Future<String?> decode(web.HTMLCanvasElement canvas);
  void dispose();
}

@JS('BarcodeDetector')
extension type _JsBarcodeDetector._(JSObject _) implements JSObject {
  external factory _JsBarcodeDetector(JSObject options);

  external static JSPromise<JSArray<JSString>> getSupportedFormats();

  external JSPromise<JSArray<JSObject>> detect(JSObject source);
}

/// Tier 1: the browser's own Shape Detection API.
class _BarcodeDetectorDecoder implements _Decoder {
  _BarcodeDetectorDecoder._(this._detector);

  final _JsBarcodeDetector _detector;

  /// The canvas goes straight to native code with no pixel readback, so a
  /// larger source is close to free here.
  @override
  int get maxSourceWidth => 2400;

  /// ML Kit locates and rectifies a barcode at any angle, so sweeping would
  /// only slow the common upright case down.
  @override
  List<int> get rotationLadder => const [0];

  static Future<_BarcodeDetectorDecoder?> tryCreate() async {
    // Absent on every browser on iOS, since WebKit does not implement it.
    if (!web.window.has('BarcodeDetector')) return null;

    try {
      final supported = (await _JsBarcodeDetector.getSupportedFormats().toDart)
          .toDart
          .map((format) => format.toDart)
          .toSet();

      final formats = _detectorFormats
          .where(supported.contains)
          .toList(growable: false);
      // Constructing with an unsupported format throws, and a detector with no
      // 1D formats at all is useless to us.
      if (formats.isEmpty) return null;

      final options = JSObject()
        ..setProperty(
          'formats'.toJS,
          [for (final format in formats) format.toJS].toJS,
        );

      return _BarcodeDetectorDecoder._(_JsBarcodeDetector(options));
    } on Object {
      return null;
    }
  }

  @override
  Future<String?> decode(web.HTMLCanvasElement canvas) async {
    final results = (await _detector.detect(canvas).toDart).toDart;

    for (final result in results) {
      final raw = result.getProperty<JSAny?>('rawValue'.toJS);
      if (raw != null && raw.isA<JSString>()) {
        final value = (raw as JSString).toDart.trim();
        if (value.isNotEmpty) return value;
      }
    }
    return null;
  }

  @override
  void dispose() {}
}

/// Tier 2: ZXing-C++ compiled to WebAssembly, running in a worker.
///
/// This is the iOS/Safari path, and it is what the plugin's built-in decoder
/// should have been all along: the real ZXing engine with `tryHarder` on,
/// rather than a JS port sampling a handful of scanlines on the UI thread.
class _WasmWorkerDecoder implements _Decoder {
  _WasmWorkerDecoder._(this._worker) {
    _worker.onmessage = _handleMessage.toJS;
    _worker.onerror = ((JSAny _) => _failAll()).toJS;
  }

  final web.Worker _worker;
  final Map<int, Completer<String?>> _pending = {};
  int _nextId = 0;
  bool _disposed = false;

  /// Every frame is read back via getImageData and transferred to the worker,
  /// so the source size is paid for in RGBA bytes each tick. 1600 keeps that
  /// near 6 MB rather than the ~13 MB a 2400-wide frame would cost.
  @override
  int get maxSourceWidth => 1600;

  /// Measured against ZXing-C++ itself: upright reads pass, 90° and 180° pass,
  /// and everything in between fails until the frame is un-rotated first. These
  /// rungs recover the whole 0-180° range.
  @override
  List<int> get rotationLadder => const [0, 20, -20, 40, -40, 60, -60];

  static Future<_WasmWorkerDecoder?> tryCreate() async {
    try {
      return _WasmWorkerDecoder._(
        web.Worker('wasm/barcode_decode_worker.js'.toJS),
      );
    } on Object {
      return null;
    }
  }

  void _handleMessage(web.MessageEvent event) {
    final data = event.data;
    if (data == null || !data.isA<JSObject>()) return;

    final payload = data as JSObject;
    final id = payload.getProperty<JSAny?>('id'.toJS);
    if (id == null || !id.isA<JSNumber>()) return;

    final completer = _pending.remove((id as JSNumber).toDartInt);
    if (completer == null || completer.isCompleted) return;

    completer.complete(_firstText(payload));
  }

  String? _firstText(JSObject payload) {
    final results = payload.getProperty<JSAny?>('results'.toJS);
    if (results == null || !results.isA<JSArray<JSObject>>()) return null;

    for (final result in (results as JSArray<JSObject>).toDart) {
      final text = result.getProperty<JSAny?>('text'.toJS);
      if (text != null && text.isA<JSString>()) {
        final value = (text as JSString).toDart.trim();
        if (value.isNotEmpty) return value;
      }
    }
    return null;
  }

  void _failAll() {
    for (final completer in _pending.values) {
      if (!completer.isCompleted) completer.complete(null);
    }
    _pending.clear();
  }

  @override
  Future<String?> decode(web.HTMLCanvasElement canvas) async {
    if (_disposed) return null;

    final context =
        canvas.getContext('2d') as web.CanvasRenderingContext2D?;
    if (context == null) return null;

    final imageData = context.getImageData(0, 0, canvas.width, canvas.height);
    // `.buffer` is not surfaced on JSUint8ClampedArray's typed interface, but
    // we need the raw ArrayBuffer to transfer it to the worker.
    final buffer = (imageData.data as JSObject).getProperty<JSObject>(
      'buffer'.toJS,
    );

    final id = _nextId++;
    final completer = Completer<String?>();
    _pending[id] = completer;

    final message = JSObject()
      ..setProperty('id'.toJS, id.toJS)
      ..setProperty('buffer'.toJS, buffer)
      ..setProperty('width'.toJS, canvas.width.toJS)
      ..setProperty('height'.toJS, canvas.height.toJS);

    // Transfer the pixel buffer instead of copying it.
    _worker.postMessage(
      message,
      JSObject()..setProperty('transfer'.toJS, <JSObject>[buffer].toJS),
    );

    // The wasm module downloads on first use; never leave the pump wedged.
    return completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        _pending.remove(id);
        return null;
      },
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _failAll();
    _worker.terminate();
  }
}
