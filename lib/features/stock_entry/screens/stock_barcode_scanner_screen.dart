import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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
  bool _popped = false;

  void _popWithValue(String? value) {
    if (_popped) return;
    _popped = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Scan barcode')),
      body: Stack(
        children: [
          MobileScanner(
            fit: BoxFit.cover,
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              if (barcodes.isEmpty) return;

              final raw = barcodes.first.rawValue;
              final value = raw?.trim();
              if (value == null || value.isEmpty) return;

              _popWithValue(value);
            },
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Card(
                  color: colorScheme.surfaceContainerHigh,
                  child: const Padding(
                    padding: EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Text('Point the camera at a barcode.'),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
