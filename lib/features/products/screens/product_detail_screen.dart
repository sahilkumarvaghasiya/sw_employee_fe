import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../core/printing/barcode_label_data.dart';
import '../../../core/printing/barcode_label_layout.dart';
import '../../../core/printing/pdf_printer_service.dart';
import '../../../core/widgets/barcode_action_buttons.dart';
import '../../../core/utils/barcode_saver.dart';
import '../../../core/utils/inr_format.dart';

import '../models/product.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.product});

  final Product product;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final GlobalKey _barcodeBoundaryKey = GlobalKey();
  final PdfPrinterService _printerService = PdfPrinterService();
  bool _isDownloading = false;
  bool _isPrinting = false;

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
      final fileName = 'barcode_${_safeFileName(widget.product.barcode)}.png';
      final message = await saveBarcodePng(bytes: bytes, fileName: fileName);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not download barcode: $e')));
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  BarcodeLabelData _buildLabelData() {
    final product = widget.product;

    return BarcodeLabelData(
      itemName: product.name,
      barcode: product.barcode,
      price: formatInr(product.price, decimalDigits: 2),
      subtitleLines: <String>[
        if (product.companyName.isNotEmpty) product.companyName,
        if (product.size.isNotEmpty) 'Size: ${product.size}',
        if (product.color.isNotEmpty) 'Colour: ${product.color}',
      ],
    );
  }

  Future<void> _printBarcode() async {
    if (_isPrinting) return;
    setState(() => _isPrinting = true);

    try {
      await _printerService.printBarcodeLabel(
        data: _buildLabelData(),
        layout: const BarcodeLabelLayout(),
        jobName: 'barcode_${_safeFileName(widget.product.barcode)}',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text('Could not print barcode: $e')));
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final product = widget.product;
    final priceLabel = formatInr(product.price, decimalDigits: 2);
    final purchasePriceLabel = formatInr(
      product.purchasePrice,
      decimalDigits: 2,
    );
    final genderText = product.gender?.label;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withAlpha(12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.inventory_2_outlined,
                          color: colorScheme.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                height: 1.05,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              product.companyName.isEmpty
                                  ? '—'
                                  : product.companyName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                if (genderText != null)
                                  _TagChip(
                                    icon: Icons.people_alt_outlined,
                                    text: genderText,
                                    background: colorScheme.primary.withAlpha(
                                      12,
                                    ),
                                    foreground: colorScheme.primary,
                                  ),
                                _TagChip(
                                  icon: Icons.straighten_outlined,
                                  text: product.size,
                                  background: colorScheme.surface,
                                  foreground: colorScheme.onSurfaceVariant,
                                ),
                                _TagChip(
                                  icon: Icons.palette_outlined,
                                  text: product.color,
                                  background: colorScheme.surface,
                                  foreground: colorScheme.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withAlpha(8),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Text(
                              'Price',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              priceLabel,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              'Purchase Price',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              purchasePriceLabel,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Barcode',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  RepaintBoundary(
                    key: _barcodeBoundaryKey,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withAlpha(80),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Barcode: ${product.barcode}',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Stock: ${product.quantityInStock}',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          BarcodeWidget(
                            barcode: Barcode.code128(),
                            data: product.barcode,
                            drawText: true,
                            color: colorScheme.onSurface,
                            backgroundColor: colorScheme.surface,
                            errorBuilder: (context, error) {
                              return Text(
                                'Invalid barcode',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: colorScheme.error,
                                  fontWeight: FontWeight.w700,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  BarcodeActionButtons(
                    isDownloading: _isDownloading,
                    isPrinting: _isPrinting,
                    onDownload: _downloadBarcode,
                    onPrint: _printBarcode,
                    downloadLabel: 'Download',
                    printLabel: 'Print',
                  ),
                  const SizedBox(height: 18),
                  _DetailRow(
                    label: 'Quantity in stock',
                    value: product.quantityInStock.toString(),
                  ),
                  _DetailRow(label: 'Size', value: product.size),
                  _DetailRow(label: 'Colour', value: product.color),
                  _DetailRow(
                    label: 'Gender',
                    value: product.gender?.label ?? '—',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.icon,
    required this.text,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 6),
          Text(
            text,
            style: theme.textTheme.labelMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
