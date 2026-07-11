import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/utils/barcode_scan_validator.dart';
import '../../../core/widgets/barcode_scanner_view.dart';

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
  late final MobileScannerController _scannerController =
      createBarcodeScannerController(
    autoStart: true,
    profile: BarcodeScanProfile.stockEntry,
  );
  final TextEditingController _manualBarcodeController = TextEditingController();
  final FocusNode _manualBarcodeFocusNode = FocusNode();

  bool _isClosing = false;

  @override
  void dispose() {
    _scannerController.dispose();
    _manualBarcodeController.dispose();
    _manualBarcodeFocusNode.dispose();
    super.dispose();
  }

  Future<void> _closeWithValue(String? value) async {
    if (_isClosing || !mounted) return;
    _isClosing = true;

    try {
      await _scannerController.stop();
    } catch (_) {
      // Camera may already be stopped when leaving the screen.
    }

    if (!mounted) return;
    Navigator.of(context).pop(value);
  }

  void _submitManualBarcode() {
    if (_isClosing) return;

    final value = _manualBarcodeController.text.trim();
    if (value.isEmpty) {
      _manualBarcodeFocusNode.requestFocus();
      return;
    }

    unawaited(_closeWithValue(value));
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
                        controller: _manualBarcodeController,
                        focusNode: _manualBarcodeFocusNode,
                        enabled: !_isClosing,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: 'Type barcode manually',
                          hintText: 'e.g. 2510077869 or R R33194',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _submitManualBarcode(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: _isClosing ? null : _submitManualBarcode,
                      child: const Text('Use'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: BarcodeScannerView(
              controller: _scannerController,
              profile: BarcodeScanProfile.stockEntry,
              enabled: !_isClosing,
              requireManualConfirm: false,
              hintText:
                  'Point the camera at the barcode. It will open automatically when detected.',
              onBarcodeConfirmed: (value) {
                unawaited(_closeWithValue(value));
              },
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
          ),
        ],
      ),
    );
  }
}
