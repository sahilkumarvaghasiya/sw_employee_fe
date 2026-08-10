import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/barcode_scan_validator.dart';

/// Stock-entry barcode scanner. Uses [mobile_scanner] with a scan frame so
/// detection focuses on the barcode inside the green rectangle.
class StockBarcodeScannerScreen extends StatefulWidget {
  const StockBarcodeScannerScreen({super.key});

  static Route<String?> route() {
    return MaterialPageRoute<String?>(
      settings: const RouteSettings(name: '/stock-entry/barcode-scanner'),
      builder: (_) => const StockBarcodeScannerScreen(),
    );
  }

  @override
  State<StockBarcodeScannerScreen> createState() =>
      _StockBarcodeScannerScreenState();
}

class _StockBarcodeScannerScreenState extends State<StockBarcodeScannerScreen> {
  static final _profile = BarcodeScanProfile.stockEntry;
  static const _cameraRestartIdleDelay = Duration(seconds: 4);
  static const _cameraRestartCooldown = Duration(seconds: 8);
  static const _scanHints = [
    'Move farther if bars look blurred',
    'Move closer if bars look very small',
    'Tilt label to remove glare / reflection',
    'Align barcode bars in the green frame',
  ];

  late final MobileScannerController _controller = MobileScannerController(
    autoStart: false,
    formats: _profile.formats,
    detectionSpeed: _profile.detectionSpeed,
    detectionTimeoutMs: _profile.detectionTimeoutMs,
    returnImage: false,
  );

  late final BarcodeScanValidator _validator = BarcodeScanValidator(
    profile: _profile,
  );

  final TextEditingController _manualController = TextEditingController();
  final FocusNode _manualFocus = FocusNode();

  bool _isClosing = false;
  double _zoom = 0;
  bool _torchOn = false;
  String? _lastShownPending;
  int _lastShownProgress = 0;
  int _hintIndex = 0;
  Timer? _hintTimer;
  Timer? _cameraHealthTimer;
  DateTime? _lastDetectAt;
  DateTime? _lastRestartAt;
  bool _restartInFlight = false;

  @override
  void initState() {
    super.initState();
    unawaited(_controller.start());
    _hintTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || _isClosing) return;
      setState(() {
        _hintIndex = (_hintIndex + 1) % _scanHints.length;
      });
    });
    _cameraHealthTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_maybeRestartCamera());
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _cameraHealthTimer?.cancel();
    unawaited(_controller.dispose());
    _manualController.dispose();
    _manualFocus.dispose();
    super.dispose();
  }

  Future<void> _closeWithValue(String value) async {
    if (_isClosing || !mounted) return;

    final normalized = normalizeStockBarcodeValue(value);
    if (normalized.isEmpty) return;

    _isClosing = true;
    _validator.reset();

    if (!mounted) return;
    Navigator.of(context).pop(normalized);

    try {
      await _controller.stop();
    } catch (_) {}
  }

  void _submitManual() {
    if (_isClosing) return;
    final value = _manualController.text.trim();
    if (value.isEmpty) {
      _manualFocus.requestFocus();
      return;
    }
    unawaited(_closeWithValue(value));
  }

  Future<void> _adjustZoom(double delta) async {
    final next = (_zoom + delta).clamp(0.0, 1.0);
    try {
      await _controller.setZoomScale(next);
      if (mounted) setState(() => _zoom = next);
    } catch (_) {}
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
      if (mounted) {
        setState(() => _torchOn = !_torchOn);
      }
    } catch (_) {}
  }

  Future<void> _maybeRestartCamera() async {
    if (_isClosing || _restartInFlight) return;
    final pending = _validator.pendingValue;
    if (pending != null && _validator.consecutiveCount > 0) return;

    final idleSince = _lastDetectAt;
    if (idleSince == null ||
        DateTime.now().difference(idleSince) < _cameraRestartIdleDelay) {
      return;
    }

    if (_lastRestartAt != null &&
        DateTime.now().difference(_lastRestartAt!) < _cameraRestartCooldown) {
      return;
    }

    _restartInFlight = true;
    _lastRestartAt = DateTime.now();
    try {
      await _controller.stop();
      if (_isClosing || !mounted) return;
      _validator.reset();
      _lastShownPending = null;
      _lastShownProgress = 0;
      await _controller.start();
    } catch (_) {
      // Keep scanner usable even if restart fails on device.
    } finally {
      _restartInFlight = false;
    }
  }

  void _onDetect(BarcodeCapture capture, Size layoutSize, Rect scanWindow) {
    if (_isClosing) return;
    _lastDetectAt = DateTime.now();

    final value = pickStockBarcodeValue(
      capture.barcodes,
      layoutSize: layoutSize,
      textureSize: capture.size,
      scanWindow: scanWindow,
    );
    if (value == null) return;

    final accepted = _validator.registerRead(value);
    if (accepted != null) {
      unawaited(_closeWithValue(accepted));
      return;
    }

    final pending = _validator.pendingValue;
    final progress = _validator.consecutiveCount;
    if (pending == _lastShownPending && progress == _lastShownProgress) return;

    _lastShownPending = pending;
    _lastShownProgress = progress;
    if (mounted) setState(() {});
  }

  String _statusText() {
    if (_isClosing) return 'Opening item form…';

    final pending = _validator.pendingValue;
    final progress = _validator.consecutiveCount;
    final required = _validator.requiredConsecutiveReads;

    if (pending != null && progress > 0 && progress < required) {
      return 'Hold steady… $progress/$required';
    }

    return _scanHints[_hintIndex];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final pending = _validator.pendingValue;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan barcode'),
        actions: kIsWeb
            ? null
            : [
                IconButton(
                  tooltip: 'Zoom out',
                  onPressed:
                      _isClosing ? null : () => unawaited(_adjustZoom(-0.12)),
                  icon: const Icon(Icons.zoom_out_rounded),
                ),
                IconButton(
                  tooltip: 'Zoom in',
                  onPressed:
                      _isClosing ? null : () => unawaited(_adjustZoom(0.12)),
                  icon: const Icon(Icons.zoom_in_rounded),
                ),
                IconButton(
                  tooltip: _torchOn ? 'Turn flash off' : 'Turn flash on',
                  onPressed: _isClosing ? null : () => unawaited(_toggleTorch()),
                  icon: Icon(
                    _torchOn
                        ? Icons.flash_on_rounded
                        : Icons.flash_off_rounded,
                  ),
                ),
              ],
      ),
      body: Column(
        children: [
          Material(
            elevation: 2,
            color: colorScheme.surfaceContainerHigh,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _manualController,
                        focusNode: _manualFocus,
                        enabled: !_isClosing,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Type barcode manually',
                          hintText: 'Barcode number',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _submitManual(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: _isClosing ? null : _submitManual,
                      child: const Text('Use'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final layoutSize = constraints.biggest;
                final scanWindow =
                    computeBarcodeScanWindow(layoutSize, _profile);

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      controller: _controller,
                      fit: BoxFit.cover,
                      onDetect: (capture) =>
                          _onDetect(capture, layoutSize, scanWindow),
                      errorBuilder: (context, error, child) {
                        return Container(
                          color: colorScheme.surfaceContainerHighest,
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.camera_alt_outlined,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Camera unavailable',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    IgnorePointer(
                      child: CustomPaint(
                        painter: _StockScanFramePainter(scanWindow: scanWindow),
                        size: layoutSize,
                      ),
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: Card(
                        color: colorScheme.surfaceContainerHigh.withValues(
                          alpha: 0.94,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _statusText(),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (pending != null && !_isClosing) ...[
                                const SizedBox(height: 6),
                                Text(
                                  pending,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_isClosing)
                      const Positioned.fill(
                        child: ColoredBox(
                          color: Color(0x55000000),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.emerald,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StockScanFramePainter extends CustomPainter {
  _StockScanFramePainter({required this.scanWindow});

  final Rect scanWindow;

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.45);
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutoutPath = Path()
      ..addRRect(RRect.fromRectAndRadius(scanWindow, const Radius.circular(12)));

    canvas.drawPath(
      Path.combine(PathOperation.difference, backgroundPath, cutoutPath),
      overlayPaint,
    );

    final borderPaint = Paint()
      ..color = AppColors.emerald
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawRRect(
      RRect.fromRectAndRadius(scanWindow, const Radius.circular(12)),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _StockScanFramePainter oldDelegate) {
    return oldDelegate.scanWindow != scanWindow;
  }
}
