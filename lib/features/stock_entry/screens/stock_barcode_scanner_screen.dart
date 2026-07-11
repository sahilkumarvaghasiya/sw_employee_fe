import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/barcode_scan_validator.dart';

/// Lightweight stock-entry scanner. Uses the camera only — no background
/// image decoding that can freeze the UI on web/mobile.
///
/// Scan flow never generates random numbers. Values come only from:
/// 1) camera barcode detection, or 2) manual user input.
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
  final BarcodeScanProfile _profile = BarcodeScanProfile.stockEntry;

  late final MobileScannerController _controller;

  late final BarcodeScanValidator _validator = BarcodeScanValidator(
    profile: _profile,
  );

  final TextEditingController _manualController = TextEditingController();
  final FocusNode _manualFocus = FocusNode();

  bool _isClosing = false;
  double _zoom = 0;
  DateTime? _cameraReadyAt;
  int _hintIndex = 0;
  Timer? _hintTimer;

  static const _distanceHints = [
    'Horizontal or vertical barcode — any angle works.',
    'Works at different heights — move closer or farther until the barcode is clear.',
    'Hold steady until the same number shows 2/2.',
    'Tilt the label slightly to remove glare.',
  ];

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      autoStart: false,
      formats: _profile.formats,
      detectionSpeed: _profile.detectionSpeed,
      detectionTimeoutMs: _profile.detectionTimeoutMs,
      returnImage: false,
      cameraResolution: kIsWeb ? null : const Size(1920, 1080),
    );
    _hintTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || _isClosing) return;
      setState(() {
        _hintIndex = (_hintIndex + 1) % _distanceHints.length;
      });
    });
    unawaited(_startCamera());
  }

  Future<void> _startCamera() async {
    try {
      await _controller.start();
    } catch (_) {
      // errorBuilder on MobileScanner will show fallback UI.
    } finally {
      if (mounted) {
        setState(() {
          _cameraReadyAt = DateTime.now();
        });
      }
    }
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
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
    setState(() {});

    try {
      await _controller.stop();
    } catch (_) {}

    if (!mounted) return;
    Navigator.of(context).pop(normalized);
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

  bool get _cameraWarmingUp {
    final readyAt = _cameraReadyAt;
    if (readyAt == null) return true;
    return DateTime.now().difference(readyAt) < const Duration(milliseconds: 500);
  }

  void _onDetect(BarcodeCapture capture, Size layoutSize) {
    if (_isClosing || _cameraWarmingUp) return;

    final bestValue = pickBestStockBarcodeValue(
      capture.barcodes,
      layoutSize: layoutSize,
    );
    if (bestValue == null) return;

    final accepted = _validator.registerRead(bestValue);
    if (accepted != null) {
      unawaited(_closeWithValue(accepted));
      return;
    }

    if (mounted) setState(() {});
  }

  String _statusText() {
    if (_isClosing) return 'Opening item form…';
    if (_cameraWarmingUp) return 'Starting camera…';

    final pending = _validator.pendingValue;
    final progress = _validator.consecutiveCount;
    final required = _validator.requiredConsecutiveReads;

    if (pending != null && progress > 0 && progress < required) {
      return 'Hold steady… $progress/$required';
    }
    if (pending != null && progress >= required) {
      return 'Barcode detected';
    }

    return _distanceHints[_hintIndex];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final pending = _validator.pendingValue;
    final progress = _validator.consecutiveCount;
    final required = _validator.requiredConsecutiveReads;

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
                          hintText: 'e.g. 2510077869 or R R33194',
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
                      onDetect: (capture) => _onDetect(capture, layoutSize),
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
                                const SizedBox(height: 8),
                                Text(
                                  error.errorCode.name,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
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
                        painter: _StockScanGuidePainter(
                          scanWindow: scanWindow,
                        ),
                        size: layoutSize,
                      ),
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (pending != null &&
                              !_isClosing &&
                              progress > 0 &&
                              progress < required)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  minHeight: 4,
                                  value: progress / required,
                                  backgroundColor: colorScheme.surface
                                      .withValues(alpha: 0.35),
                                  color: AppColors.emerald,
                                ),
                              ),
                            ),
                          Card(
                            color: colorScheme.surfaceContainerHigh.withValues(
                              alpha: 0.94,
                            ),
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
                                      style:
                                          theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
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

class _StockScanGuidePainter extends CustomPainter {
  _StockScanGuidePainter({required this.scanWindow});

  final Rect scanWindow;

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.35);
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutoutPath = Path()
      ..addRRect(RRect.fromRectAndRadius(scanWindow, const Radius.circular(14)));

    canvas.drawPath(
      Path.combine(PathOperation.difference, backgroundPath, cutoutPath),
      overlayPaint,
    );

    final borderPaint = Paint()
      ..color = AppColors.emerald
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawRRect(
      RRect.fromRectAndRadius(scanWindow, const Radius.circular(14)),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _StockScanGuidePainter oldDelegate) {
    return oldDelegate.scanWindow != scanWindow;
  }
}
