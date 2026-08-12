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

/// Pad the scan window before cropping — users rarely centre the barcode
/// exactly, and a barcode clipped at the edge decodes as nothing.
const double _cropPadding = 0.28;

/// Upper bound on the crop we hand the decoder. Bigger costs time without
/// adding pixels per bar, since the crop is already magnified.
const int _maxCropWidth = 1600;

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

      final canvas = _captureFrame();
      if (canvas == null || _disposed) return;

      final value = await decoder.decode(canvas);
      if (value == null || value.isEmpty || _disposed || !_enabled) return;

      onBarcode(value);
    } on Object {
      // Frames without a barcode are the common case, and a transient canvas or
      // worker failure must not kill the pump.
    } finally {
      _busy = false;
    }
  }

  /// Draws the scan window region of the preview into a reusable canvas,
  /// magnifying it when the crop is small.
  ///
  /// Cropping is what makes the green frame meaningful: it raises the pixels
  /// per bar the decoder sees and removes the size chart, price and address
  /// text from the image entirely.
  web.HTMLCanvasElement? _captureFrame() {
    final video = findLiveScannerVideo();
    if (video == null) return null;

    final videoWidth = video.videoWidth;
    final videoHeight = video.videoHeight;
    if (videoWidth <= 0 || videoHeight <= 0) return null;

    final crop = _cropInVideoPixels(
      Size(videoWidth.toDouble(), videoHeight.toDouble()),
    );

    final scale = math.min(
      2.0,
      _maxCropWidth / math.max(crop.width, 1),
    ).clamp(1.0, 2.0);
    final targetWidth = (crop.width * scale).round().clamp(16, _maxCropWidth);
    final targetHeight = (crop.height * scale).round().clamp(16, _maxCropWidth);

    final canvas = _ensureCanvas(targetWidth, targetHeight);
    final context = _context;
    if (context == null) return null;

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

    final padded = raw.inflate(math.max(raw.width, raw.height) * _cropPadding);
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
