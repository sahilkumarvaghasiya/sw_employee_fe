import 'package:flutter/material.dart';

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
  late final _scannerController = createBarcodeScannerController(
    autoStart: true,
    profile: BarcodeScanProfile.stockEntry,
  );
  final TextEditingController _manualBarcodeController = TextEditingController();

  bool _popped = false;

  @override
  void dispose() {
    _scannerController.dispose();
    _manualBarcodeController.dispose();
    super.dispose();
  }

  void _popWithValue(String? value) {
    if (_popped) return;
    _popped = true;
    Navigator.of(context).pop(value);
  }

  void _submitManualBarcode() {
    final value = _manualBarcodeController.text.trim();
    if (value.isEmpty) return;
    _popWithValue(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Scan barcode')),
      body: Column(
        children: [
          Expanded(
            child: BarcodeScannerView(
              controller: _scannerController,
              profile: BarcodeScanProfile.stockEntry,
              requireManualConfirm: false,
              hintText:
                  'Point the camera at the barcode. It will open automatically when detected.',
              onBarcodeConfirmed: _popWithValue,
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
          Material(
            elevation: 8,
            color: colorScheme.surfaceContainerHigh,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _manualBarcodeController,
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
                      onPressed: _submitManualBarcode,
                      child: const Text('Use'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
