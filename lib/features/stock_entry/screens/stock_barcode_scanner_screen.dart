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
  late final _scannerController = createBarcodeScannerController(autoStart: true);

  bool _popped = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _popWithValue(String? value) {
    if (_popped) return;
    _popped = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan barcode')),
      body: BarcodeScannerView(
        controller: _scannerController,
        requireManualConfirm: true,
        hintText:
            'Align the barcode inside the frame and hold steady until it is detected.',
        onBarcodeConfirmed: _popWithValue,
        errorBuilder: (context, error, child) {
          final colorScheme = Theme.of(context).colorScheme;
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
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
