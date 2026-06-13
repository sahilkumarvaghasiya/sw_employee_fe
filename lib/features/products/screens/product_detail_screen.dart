import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../core/printing/barcode_label_data.dart';
import '../../../core/printing/barcode_label_layout.dart';
import '../../../core/printing/pdf_printer_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_surface_card.dart';
import '../../../core/widgets/barcode_action_buttons.dart';
import '../../../core/utils/barcode_saver.dart';
import '../../../core/utils/inr_format.dart';
import '../../billing/widgets/billing_ui.dart';

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
    final isDark = theme.brightness == Brightness.dark;

    final product = widget.product;
    final priceLabel = formatInr(product.price, decimalDigits: 2);
    final purchasePriceLabel = formatInr(
      product.purchasePrice,
      decimalDigits: 2,
    );
    final genderText = product.gender?.label;

    return Scaffold(
      backgroundColor: isDark ? AppColors.slate950 : AppColors.slate50,
      appBar: AppBar(
        title: Text(
          product.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          BillingPayableHero(
            label: 'Selling price',
            amount: priceLabel,
            subtitle: product.companyName.isNotEmpty
                ? product.companyName
                : null,
          ),
          const SizedBox(height: 12),
          AppSurfaceCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (genderText != null)
                      _TagChip(
                        icon: Icons.people_alt_outlined,
                        text: genderText,
                        background: AppColors.emerald.withValues(alpha: 0.1),
                        foreground: AppColors.emeraldDark,
                      ),
                    _TagChip(
                      icon: Icons.straighten_outlined,
                      text: product.size,
                      background: colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      foreground: colorScheme.onSurfaceVariant,
                    ),
                    _TagChip(
                      icon: Icons.palette_outlined,
                      text: product.color,
                      background: colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      foreground: colorScheme.onSurfaceVariant,
                    ),
                    _TagChip(
                      icon: Icons.inventory_2_outlined,
                      text: 'Stock ${product.quantityInStock}',
                      background: colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      foreground: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                BillingSummaryLine(
                  label: 'Purchase price',
                  value: purchasePriceLabel,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Barcode',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          AppSurfaceCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  product.barcode,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                RepaintBoundary(
                  key: _barcodeBoundaryKey,
                  child: BarcodeWidget(
                    barcode: Barcode.code128(),
                    data: product.barcode,
                    drawText: true,
                    color: colorScheme.onSurface,
                    backgroundColor: Colors.transparent,
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
              ],
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
