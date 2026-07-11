import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/barcode_scan_validator.dart';

/// Stock-entry barcode scanner. Uses [mobile_scanner] only — reads [Barcode.rawValue]
/// from the camera and accepts on the first valid 1D barcode detection.
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
  static final _formats = BarcodeScanProfile.stockEntry.formats;

  late final MobileScannerController _controller = MobileScannerController(
    autoStart: false,
    formats: _formats,
    detectionSpeed: DetectionSpeed.unrestricted,
    detectionTimeoutMs: kIsWeb ? 200 : 300,
    returnImage: false,
  );

  final TextEditingController _manualController = TextEditingController();
  final FocusNode _manualFocus = FocusNode();

  bool _isClosing = false;
  double _zoom = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_controller.start());
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

  Future<void> _adjustZoom(double delta) async {
    final next = (_zoom + delta).clamp(0.0, 1.0);
    try {
      await _controller.setZoomScale(next);
      if (mounted) setState(() => _zoom = next);
    } catch (_) {}
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isClosing) return;

    final value = extractStockBarcodeValue(capture.barcodes);
    if (value == null) return;

    unawaited(_closeWithValue(value));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
                            : 'Point the camera at the barcode',
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
