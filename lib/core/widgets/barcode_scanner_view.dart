import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../theme/app_colors.dart';
import '../utils/barcode_scan_validator.dart';

/// Reusable camera scanner with focus window, stable-read validation, and torch.
class BarcodeScannerView extends StatefulWidget {
  const BarcodeScannerView({
    super.key,
    required this.controller,
    required this.onBarcodeConfirmed,
    this.enabled = true,
    this.requireManualConfirm = false,
    this.hintText = 'Align the barcode inside the frame and hold steady.',
    this.errorBuilder,
  });

  final MobileScannerController controller;
  final ValueChanged<String> onBarcodeConfirmed;
  final bool enabled;
  final bool requireManualConfirm;
  final String hintText;
  final MobileScannerErrorBuilder? errorBuilder;

  @override
  State<BarcodeScannerView> createState() => _BarcodeScannerViewState();
}

class _BarcodeScannerViewState extends State<BarcodeScannerView> {
  final BarcodeScanValidator _validator = BarcodeScanValidator();

  String? _awaitingConfirmValue;
  bool _torchOn = false;

  @override
  void didUpdateWidget(covariant BarcodeScannerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && oldWidget.enabled) {
      _resetScanState();
    }
  }

  void _resetScanState() {
    _validator.reset();
    if (_awaitingConfirmValue != null) {
      setState(() => _awaitingConfirmValue = null);
    }
  }

  Future<void> _toggleTorch() async {
    try {
      await widget.controller.toggleTorch();
      if (!mounted) return;
      setState(
        () => _torchOn = widget.controller.value.torchState == TorchState.on,
      );
    } catch (_) {
      // Torch not supported on this platform.
    }
  }

  void _handleDetect(BarcodeCapture capture, Size layoutSize) {
    if (!widget.enabled || _awaitingConfirmValue != null) return;

    final scanWindow = computeBarcodeScanWindow(layoutSize);
    final barcode = pickBestBarcode(
      capture.barcodes,
      layoutSize: layoutSize,
      scanWindow: scanWindow,
    );

    final value = barcode?.rawValue?.trim();
    if (value == null || value.isEmpty) return;

    final accepted = _validator.registerRead(value);
    if (accepted == null) {
      if (mounted) setState(() {});
      return;
    }

    if (widget.requireManualConfirm) {
      setState(() => _awaitingConfirmValue = accepted);
      return;
    }

    widget.onBarcodeConfirmed(accepted);
    _validator.reset();
  }

  void _confirmPending() {
    final value = _awaitingConfirmValue;
    if (value == null) return;
    widget.onBarcodeConfirmed(value);
    _resetScanState();
  }

  void _rejectPending() {
    _resetScanState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final layoutSize = constraints.biggest;
        final scanWindow = computeBarcodeScanWindow(layoutSize);

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
            Positioned(
              top: 12,
              right: 12,
              child: _TorchButton(
                enabled: widget.enabled,
                torchOn: _torchOn,
                onPressed: _toggleTorch,
              ),
            ),
            if (_awaitingConfirmValue != null)
              _ConfirmOverlay(
                value: _awaitingConfirmValue!,
                onConfirm: _confirmPending,
                onRescan: _rejectPending,
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

    String statusText = widget.hintText;
    if (_awaitingConfirmValue != null) {
      statusText = 'Confirm the barcode below.';
    } else if (pending != null && progress > 0 && progress < required) {
      statusText = 'Hold steady… $progress/$required';
    } else if (pending != null && progress >= required) {
      statusText = 'Barcode detected';
    }

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

class _TorchButton extends StatelessWidget {
  const _TorchButton({
    required this.enabled,
    required this.torchOn,
    required this.onPressed,
  });

  final bool enabled;
  final bool torchOn;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        tooltip: torchOn ? 'Turn off flashlight' : 'Turn on flashlight',
        onPressed: enabled ? onPressed : null,
        icon: Icon(torchOn ? Icons.flashlight_on : Icons.flashlight_off),
      ),
    );
  }
}

class _ConfirmOverlay extends StatelessWidget {
  const _ConfirmOverlay({
    required this.value,
    required this.onConfirm,
    required this.onRescan,
  });

  final String value;
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
                    'Barcode detected',
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
