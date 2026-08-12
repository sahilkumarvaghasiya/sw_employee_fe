import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';

/// Print-ready barcode label shown on screen and captured for the PNG
/// download, so the downloaded image carries the same header, price and size
/// lines as the printed label.
///
/// Colours are fixed (black on white) instead of theme-driven: the capture is
/// meant to be printed and stuck on a product, and a dark-theme capture would
/// otherwise download as white ink on a transparent background.
class BarcodeLabelPreview extends StatelessWidget {
  const BarcodeLabelPreview({
    super.key,
    required this.barcode,
    this.barcodeUrl,
    this.headerLines = const <String>[],
    this.price,
  });

  static const Color _ink = Color(0xFF111111);
  static const Color _paper = Colors.white;

  final String barcode;
  final String? barcodeUrl;

  /// Lines rendered above the barcode (item name, size, colour, ...).
  final List<String> headerLines;

  /// Preformatted price, e.g. `₹499.00`. Hidden when null or blank.
  final String? price;

  @override
  Widget build(BuildContext context) {
    final lines = headerLines
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    final priceText = price?.trim() ?? '';
    final hasHeader = lines.isNotEmpty || priceText.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                line,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (priceText.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: lines.isEmpty ? 0 : 2),
              child: Text(
                'Price: $priceText',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          if (hasHeader) const SizedBox(height: 10),
          _buildBarcode(),
        ],
      ),
    );
  }

  Widget _buildBarcode() {
    final url = barcodeUrl?.trim() ?? '';
    if (url.isEmpty) return _fallbackBarcode();

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _fallbackBarcode(),
      ),
    );
  }

  Widget _fallbackBarcode() {
    return BarcodeWidget(
      barcode: Barcode.code128(),
      data: barcode,
      drawText: true,
      color: _ink,
      backgroundColor: _paper,
      errorBuilder: (context, error) => const Text(
        'Invalid barcode',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Color(0xFFB3261E),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
