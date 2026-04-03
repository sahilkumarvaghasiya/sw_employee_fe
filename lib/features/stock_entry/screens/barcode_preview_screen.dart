import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../core/utils/barcode_saver.dart';

class BarcodePreviewScreen extends StatefulWidget {
  const BarcodePreviewScreen({super.key, required this.barcode});

  final String barcode;

  static Route<void> route({required String barcode}) {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/stock-entry/barcode-preview'),
      builder: (_) => BarcodePreviewScreen(barcode: barcode),
    );
  }

  @override
  State<BarcodePreviewScreen> createState() => _BarcodePreviewScreenState();
}

class _BarcodePreviewScreenState extends State<BarcodePreviewScreen> {
  final GlobalKey _barcodeBoundaryKey = GlobalKey();
  bool _isDownloading = false;

  String _safeFileName(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return cleaned.isEmpty ? 'barcode' : cleaned;
  }

  Future<Uint8List> _captureBarcodePngBytes() async {
    final boundaryContext = _barcodeBoundaryKey.currentContext;
    final boundary =
        boundaryContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('Barcode is not ready to capture yet');
    }

    final pixelRatio = View.of(context).devicePixelRatio;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Failed to encode barcode as PNG');
    }

    return byteData.buffer.asUint8List();
  }

  Future<void> _downloadBarcode() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);

    try {
      final bytes = await _captureBarcodePngBytes();
      final fileName = 'barcode_${_safeFileName(widget.barcode)}.png';
      final message = await saveBarcodePng(bytes: bytes, fileName: fileName);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(content: Text('Could not download barcode: $e')),
        );
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  void _printBarcode() {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(content: Text('Print option will be connected later.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Barcode')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Generated barcode',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Print this barcode and attach it to the product.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  RepaintBoundary(
                    key: _barcodeBoundaryKey,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: BarcodeWidget(
                        barcode: Barcode.code128(),
                        data: widget.barcode,
                        drawText: true,
                        color: colorScheme.onSurface,
                        backgroundColor: colorScheme.surface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.barcode,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isDownloading ? null : _downloadBarcode,
                  icon: _isDownloading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_rounded),
                  label: Text(_isDownloading ? 'Downloading...' : 'Download'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _printBarcode,
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Print'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
