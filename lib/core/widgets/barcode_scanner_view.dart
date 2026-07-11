import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../theme/app_colors.dart';
import '../utils/barcode_frame_capture.dart';
import '../utils/barcode_frame_decoder.dart';
import '../utils/barcode_label_text_reader.dart';
import '../utils/barcode_scan_validator.dart';

/// Reusable camera scanner with focus window and stable-read validation.
class BarcodeScannerView extends StatefulWidget {
  const BarcodeScannerView({
    super.key,
    required this.controller,
    required this.onBarcodeConfirmed,
    this.profile = BarcodeScanProfile.billing,
    this.enabled = true,
    this.requireManualConfirm = false,
    this.hintText = 'Align the barcode inside the frame and hold steady.',
    this.errorBuilder,
  });

  final MobileScannerController controller;
  final ValueChanged<String> onBarcodeConfirmed;
  final BarcodeScanProfile profile;
  final bool enabled;
  final bool requireManualConfirm;
  final String hintText;
  final MobileScannerErrorBuilder? errorBuilder;

  @override
  State<BarcodeScannerView> createState() => _BarcodeScannerViewState();
}

class _BarcodeScannerViewState extends State<BarcodeScannerView> {
  static const _secondaryDecodeIdleDelay = Duration(seconds: 2);
  static const _secondaryDecodeInterval = Duration(milliseconds: 1200);
  static const _secondaryDecodeCooldown = Duration(milliseconds: 900);
  static const _secondaryDecodeTimeout = Duration(seconds: 3);
  static const _scanWarmupDuration = Duration(milliseconds: 700);

  late final BarcodeScanValidator _validator = BarcodeScanValidator(
    profile: widget.profile,
  );
  final BarcodeFrameDecoder _frameDecoder = const BarcodeFrameDecoder();

  String? _awaitingConfirmValue;
  String? _confirmSourceLabel;
  DateTime? _lastSuccessfulDetectAt;
  DateTime? _lastSecondaryAttemptAt;
  DateTime? _scanSessionStartedAt;
  DateTime? _scanWarmupEndsAt;
  bool _secondaryDecodeInFlight = false;
  bool _hasDeliveredBarcode = false;
  bool _isDisposing = false;
  Timer? _secondaryDecodeTimer;
  int _hintIndex = 0;
  Timer? _hintTimer;
  Uint8List? _latestFrameBytes;
  Size? _layoutSize;

  bool get _useStockWebHints =>
      kIsWeb && widget.profile.isStockEntry && _awaitingConfirmValue == null;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _scanSessionStartedAt = now;
    _scanWarmupEndsAt = now.add(_scanWarmupDuration);
    _startHintRotation();
    _scheduleSecondaryDecode();
  }

  @override
  void didUpdateWidget(covariant BarcodeScannerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && oldWidget.enabled) {
      _stopSecondaryDecode();
      _resetScanState();
    }
    if (widget.profile != oldWidget.profile) {
      _validator.reset();
    }
  }

  @override
  void dispose() {
    _isDisposing = true;
    _secondaryDecodeTimer?.cancel();
    _hintTimer?.cancel();
    super.dispose();
  }

  bool get _canAcceptScans =>
      widget.enabled &&
      !_hasDeliveredBarcode &&
      !_isDisposing &&
      mounted &&
      _awaitingConfirmValue == null;

  bool get _isWarmingUp {
    final warmupEndsAt = _scanWarmupEndsAt;
    if (warmupEndsAt == null) return false;
    return DateTime.now().isBefore(warmupEndsAt);
  }

  void _stopSecondaryDecode() {
    _secondaryDecodeTimer?.cancel();
    _secondaryDecodeTimer = null;
  }

  void _startHintRotation() {
    _hintTimer?.cancel();
    if (!_useStockWebHints) return;

    _hintTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || _awaitingConfirmValue != null) return;
      setState(() {
        _hintIndex =
            (_hintIndex + 1) % widget.profile.webScanHints.length;
      });
    });
  }

  void _scheduleSecondaryDecode() {
    _secondaryDecodeTimer?.cancel();
    if (!widget.profile.enableSecondaryDecode) return;

    _secondaryDecodeTimer = Timer.periodic(_secondaryDecodeInterval, (_) {
      unawaited(_maybeRunSecondaryDecode());
    });
  }

  bool _shouldBlockSecondaryDecode() {
    final pending = _validator.pendingValue;
    final progress = _validator.consecutiveCount;
    return pending != null && progress > 0;
  }

  bool _secondaryDecodeReady() {
    final startedAt = _scanSessionStartedAt;
    if (startedAt == null) return false;

    final lastDetect = _lastSuccessfulDetectAt;
    final idleSince = lastDetect ?? startedAt;
    return DateTime.now().difference(idleSince) >= _secondaryDecodeIdleDelay;
  }

  void _resetScanState() {
    _validator.reset();
    _lastSuccessfulDetectAt = null;
    _lastSecondaryAttemptAt = null;
    _secondaryDecodeInFlight = false;
    _latestFrameBytes = null;
    final now = DateTime.now();
    _scanSessionStartedAt = now;
    _scanWarmupEndsAt = now.add(_scanWarmupDuration);
    if (_awaitingConfirmValue != null || _confirmSourceLabel != null) {
      if (mounted) {
        setState(() {
          _awaitingConfirmValue = null;
          _confirmSourceLabel = null;
        });
      } else {
        _awaitingConfirmValue = null;
        _confirmSourceLabel = null;
      }
    }
  }

  void _deliverBarcode(String value) {
    if (_hasDeliveredBarcode || _isDisposing || !mounted) return;

    _hasDeliveredBarcode = true;
    _stopSecondaryDecode();
    _secondaryDecodeInFlight = false;

    widget.onBarcodeConfirmed(value);
  }

  void _handleDetect(BarcodeCapture capture, Size layoutSize) {
    if (!_canAcceptScans || _isWarmingUp) return;

    if (capture.image != null && capture.image!.isNotEmpty) {
      _latestFrameBytes = capture.image;
    }

    final scanWindow = computeBarcodeScanWindow(layoutSize, widget.profile);
    final barcode = pickBestBarcode(
      capture.barcodes,
      layoutSize: layoutSize,
      scanWindow: scanWindow,
      profile: widget.profile,
    );

    final value = barcode?.rawValue?.trim();
    if (value == null || value.isEmpty) return;

    final normalized = widget.profile.isStockEntry
        ? normalizeStockBarcodeValue(value)
        : value;
    if (widget.profile.isStockEntry && !isLikelyStockBarcodeValue(normalized)) {
      return;
    }

    _lastSuccessfulDetectAt = DateTime.now();
    final accepted = _validator.registerRead(normalized);
    if (accepted == null) {
      if (mounted) setState(() {});
      return;
    }

    _presentCandidate(
      accepted,
      fromPrintedText: false,
    );
  }

  void _presentCandidate(
    String value, {
    bool fromPrintedText = false,
  }) {
    final needsConfirm =
        widget.requireManualConfirm ||
        (widget.profile.isStockEntry && fromPrintedText);

    if (needsConfirm) {
      setState(() {
        _awaitingConfirmValue = value;
        _confirmSourceLabel = fromPrintedText
            ? 'Detected from label text'
            : null;
      });
      return;
    }

    _deliverBarcode(value);
  }

  Future<void> _maybeRunSecondaryDecode() async {
    if (!_canAcceptScans ||
        !widget.profile.enableSecondaryDecode ||
        _secondaryDecodeInFlight ||
        _isWarmingUp) {
      return;
    }

    final now = DateTime.now();
    if (_shouldBlockSecondaryDecode() || !_secondaryDecodeReady()) {
      return;
    }

    final lastAttempt = _lastSecondaryAttemptAt;
    if (lastAttempt != null &&
        now.difference(lastAttempt) < _secondaryDecodeCooldown) {
      return;
    }

    _secondaryDecodeInFlight = true;
    _lastSecondaryAttemptAt = now;

    try {
      final layoutSize = _layoutSize;
      if (layoutSize == null || !_canAcceptScans) return;

      final scanWindow = computeBarcodeScanWindow(layoutSize, widget.profile);
      final cropRect = normalizedCropFromScanWindow(scanWindow, layoutSize);

      Uint8List? frameBytes = _latestFrameBytes;
      frameBytes ??= await captureCameraPreviewFrame(cropRect: cropRect);
      if (!_canAcceptScans || frameBytes == null || frameBytes.isEmpty) return;

      final decoded = await _frameDecoder
          .decodeFromImageBytes(
            frameBytes,
            cropRect: cropRect,
            live: true,
          )
          .timeout(_secondaryDecodeTimeout, onTimeout: () => null);
      if (!_canAcceptScans) return;

      if (decoded != null) {
        final accepted = _validator.registerRead(decoded.value);
        if (accepted != null) {
          _presentCandidate(
            accepted,
            fromPrintedText: false,
          );
          return;
        }
        if (mounted) setState(() {});
        return;
      }

      final printed = await readPrintedBarcodeNumber(frameBytes)
          .timeout(_secondaryDecodeTimeout, onTimeout: () => null);
      if (!_canAcceptScans || printed == null || printed.isEmpty) return;

      final normalized = normalizeStockBarcodeValue(printed);
      if (!isLikelyStockBarcodeValue(normalized)) return;

      _presentPrintedCandidate(normalized);
      if (mounted) setState(() {});
    } on Object {
      // Ignore decode failures/timeouts and keep the live scanner responsive.
    } finally {
      _secondaryDecodeInFlight = false;
    }
  }

  void _presentPrintedCandidate(String value) {
    if (!_canAcceptScans) return;

    final accepted = _validator.registerRead(value);
    if (accepted != null) {
      _presentCandidate(
        accepted,
        fromPrintedText: true,
      );
      return;
    }

    _presentCandidate(
      value.trim(),
      fromPrintedText: true,
    );
  }

  void _confirmPending() {
    final value = _awaitingConfirmValue;
    if (value == null || !_canAcceptScans) return;
    _deliverBarcode(value);
    _resetScanState();
  }

  void _rejectPending() {
    _resetScanState();
  }

  String _statusText() {
    if (_awaitingConfirmValue != null) {
      return _confirmSourceLabel ?? 'Confirm the barcode below.';
    }

    if (_useStockWebHints) {
      return widget.profile.webScanHints[_hintIndex];
    }

    final pending = _validator.pendingValue;
    final progress = _validator.consecutiveCount;
    final required = _validator.requiredConsecutiveReads;

    if (pending != null && progress > 0 && progress < required) {
      return 'Hold steady… $progress/$required';
    }
    if (pending != null && progress >= required) {
      return 'Barcode detected';
    }

    return widget.hintText;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final layoutSize = constraints.biggest;
        _layoutSize = layoutSize;
        final scanWindow = computeBarcodeScanWindow(layoutSize, widget.profile);

        return Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: widget.controller,
              fit: BoxFit.cover,
              scanWindow: scanWindow,
              errorBuilder: widget.errorBuilder,
              overlayBuilder: (context, constraints) {
                return CustomPaint(
                  painter: _BarcodeScanOverlayPainter(
                    scanWindow: scanWindow,
                    borderColor: AppColors.emerald,
                  ),
                  size: constraints.biggest,
                );
              },
              onDetect: (capture) => _handleDetect(capture, layoutSize),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: _buildBottomPanel(theme, colorScheme),
            ),
            if (_awaitingConfirmValue != null)
              Positioned.fill(
                child: _ConfirmOverlay(
                  value: _awaitingConfirmValue!,
                  sourceLabel: _confirmSourceLabel,
                  onConfirm: _confirmPending,
                  onRescan: _rejectPending,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildBottomPanel(ThemeData theme, ColorScheme colorScheme) {
    final pending = _validator.pendingValue;
    final progress = _validator.consecutiveCount;
    final required = _validator.requiredConsecutiveReads;
    final statusText = _statusText();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (pending != null &&
            _awaitingConfirmValue == null &&
            progress > 0 &&
            progress < required)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 4,
                value: progress / required,
                backgroundColor: colorScheme.surface.withValues(alpha: 0.35),
                color: AppColors.emerald,
              ),
            ),
          ),
        Card(
          color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.94),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (pending != null && _awaitingConfirmValue == null) ...[
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
      ],
    );
  }
}

class _ConfirmOverlay extends StatelessWidget {
  const _ConfirmOverlay({
    required this.value,
    required this.onConfirm,
    required this.onRescan,
    this.sourceLabel,
  });

  final String value;
  final String? sourceLabel;
  final VoidCallback onConfirm;
  final VoidCallback onRescan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    sourceLabel ?? 'Barcode detected',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SelectableText(
                    value,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Is this the correct barcode?',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onRescan,
                          child: const Text('Scan again'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: onConfirm,
                          child: const Text('Use this'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BarcodeScanOverlayPainter extends CustomPainter {
  _BarcodeScanOverlayPainter({
    required this.scanWindow,
    required this.borderColor,
  });

  final Rect scanWindow;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.45);
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutoutPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(scanWindow, const Radius.circular(14)),
      );

    canvas.drawPath(
      Path.combine(PathOperation.difference, backgroundPath, cutoutPath),
      overlayPaint,
    );

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawRRect(
      RRect.fromRectAndRadius(scanWindow, const Radius.circular(14)),
      borderPaint,
    );

    _drawCorner(canvas, scanWindow.topLeft, 1, 1);
    _drawCorner(canvas, scanWindow.topRight, -1, 1);
    _drawCorner(canvas, scanWindow.bottomLeft, 1, -1);
    _drawCorner(canvas, scanWindow.bottomRight, -1, -1);
  }

  void _drawCorner(Canvas canvas, Offset corner, int xDir, int yDir) {
    const arm = 22.0;
    final paint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      corner,
      corner + Offset(arm * xDir, 0),
      paint,
    );
    canvas.drawLine(
      corner,
      corner + Offset(0, arm * yDir),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _BarcodeScanOverlayPainter oldDelegate) {
    return oldDelegate.scanWindow != scanWindow ||
        oldDelegate.borderColor != borderColor;
  }
}
