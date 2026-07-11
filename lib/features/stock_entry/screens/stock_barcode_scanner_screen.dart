import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/barcode_scan_validator.dart';

/// Lightweight stock-entry scanner. Uses the camera only — no background
/// image decoding that can freeze the UI on web/mobile.
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
  late final MobileScannerController _controller = MobileScannerController(
    autoStart: false,
    formats: BarcodeScanProfile.stockEntry.formats,
    detectionSpeed: DetectionSpeed.normal,
    detectionTimeoutMs: BarcodeScanProfile.stockEntry.detectionTimeoutMs,
    returnImage: false,
  );

  final TextEditingController _manualController = TextEditingController();
  final FocusNode _manualFocus = FocusNode();

  bool _isClosing = false;
  String? _lastSeenValue;
  DateTime? _cameraReadyAt;

  @override
  void initState() {
    super.initState();
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

  bool get _cameraWarmingUp {
    final readyAt = _cameraReadyAt;
    if (readyAt == null) return true;
    return DateTime.now().difference(readyAt) < const Duration(milliseconds: 500);
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isClosing || _cameraWarmingUp) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    Barcode? best;
    var bestScore = -1;

    for (final barcode in barcodes) {
      final raw = barcode.rawValue?.trim();
      if (raw == null || raw.isEmpty) continue;

      final normalized = normalizeStockBarcodeValue(raw);
      if (normalized.isEmpty) continue;

      var score = stockBarcodeValueScore(normalized);
      if (!isLikelyStockBarcodeValue(normalized)) {
        // Keep a weak fallback candidate for difficult vendor labels.
        if (normalized.length < 4) continue;
        score = 1;
      }
      if (barcode.format == BarcodeFormat.code128) score += 20;
      if (barcode.format == BarcodeFormat.code39) score += 15;

      if (score > bestScore) {
        bestScore = score;
        best = barcode;
      }
    }

    final value = best?.rawValue?.trim();
    if (value == null || value.isEmpty) return;

    final normalized = normalizeStockBarcodeValue(value);
    if (normalized.isEmpty || normalized.length < 4) return;

    // Debounce duplicate reads of the same value.
    if (_lastSeenValue == normalized) return;
    _lastSeenValue = normalized;

    unawaited(_closeWithValue(normalized));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Scan barcode')),
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
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _controller,
                  fit: BoxFit.cover,
                  onDetect: _onDetect,
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
                      child: Text(
                        _isClosing
                            ? 'Opening item form…'
                            : _cameraWarmingUp
                                ? 'Starting camera…'
                                : 'Point the camera at the barcode, or type it above.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
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
            ),
          ),
        ],
      ),
    );
  }
}
