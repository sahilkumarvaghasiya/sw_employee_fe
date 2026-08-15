import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';

import '../printing/barcode_label_data.dart';
import '../printing/barcode_label_layout.dart';

/// True-to-print preview of one label, also captured for the PNG download.
///
/// The widget mirrors the PDF built by `BarcodeLabelBuilder`: same aspect
/// ratio as the label stock, same element order, and every size scaled from
/// the same points so what the shop sees is what comes off the roll.
///
/// Colours are fixed (black on white) instead of theme-driven: the capture is
/// meant to be printed and stuck on a product, and a dark-theme capture would
/// otherwise download as white ink on a transparent background.
class BarcodeLabelPreview extends StatelessWidget {
  const BarcodeLabelPreview({
    super.key,
    required this.data,
    this.layout = BarcodeLabelLayout.label50x38,
    this.barcodeUrl,
  });

  static const Color _ink = Color(0xFF111111);
  static const Color _paper = Colors.white;

  /// Fixed line box so the height budget is arithmetic rather than a property
  /// of whichever font the platform resolves.
  static const double _lineHeight = 1.15;

  final BarcodeLabelData data;
  final BarcodeLabelLayout layout;

  /// Backend-rendered barcode image. When present it replaces the locally
  /// generated bars; it already carries the digits underneath, so the separate
  /// digits line is skipped to avoid printing them twice.
  final String? barcodeUrl;

  @override
  Widget build(BuildContext context) {
    final format = layout.pageFormat;

    // The preview stands in for a physical label, so the device's text-size
    // setting must not resize its contents — scaled-up text would overflow a
    // fixed-height label and stop matching what actually prints.
    return MediaQuery.withNoTextScaling(
      child: AspectRatio(
        aspectRatio: format.width / format.height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Points to logical pixels, so every size below stays in the same
            // proportion as the printed label.
            final scale = constraints.maxWidth / format.width;

            return Container(
              decoration: BoxDecoration(
                color: _paper,
                border: Border.all(color: const Color(0xFFE0E0E0)),
                borderRadius: BorderRadius.circular(6),
              ),
              padding: EdgeInsets.fromLTRB(
                layout.padding.left * scale,
                layout.padding.top * scale,
                layout.padding.right * scale,
                layout.padding.bottom * scale,
              ),
              child: _buildLabelBody(scale),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLabelBody(double scale) {
    final subtitleLines = layout.mergeSubtitleIntoName
        ? const <String>[]
        : data.cappedSubtitleLines(layout.maxSubtitleLines);
    final name = layout.mergeSubtitleIntoName ? data.mergedName : data.itemName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              maxLines: layout.nameMaxLines,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _ink,
                fontSize: layout.nameFontSize * scale,
                height: _lineHeight,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitleLines.isNotEmpty) ...[
              SizedBox(height: 2 * scale),
              for (final line in subtitleLines)
                Padding(
                  padding: EdgeInsets.only(bottom: 1 * scale),
                  child: Text(
                    line,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _ink,
                      fontSize: layout.subtitleFontSize * scale,
                      height: _lineHeight,
                    ),
                  ),
                ),
            ],
            if (data.hasPrice) ...[
              SizedBox(height: 2 * scale),
              Text(
                'Price: ${data.trimmedPrice}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _ink,
                  fontSize: layout.priceFontSize * scale,
                  height: _lineHeight,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
        _buildBarcodeBlock(scale),
      ],
    );
  }

  Widget _buildBarcodeBlock(double scale) {
    final url = barcodeUrl?.trim() ?? '';
    final barcodeHeight = layout.barcodeHeight * scale;

    if (url.isNotEmpty) {
      return SizedBox(
        height: barcodeHeight + (layout.codeFontSize + 2) * scale,
        child: Image.network(
          url,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) =>
              _localBarcode(scale, barcodeHeight),
        ),
      );
    }

    return _localBarcode(scale, barcodeHeight);
  }

  Widget _localBarcode(double scale, double barcodeHeight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: barcodeHeight,
          child: BarcodeWidget(
            barcode: Barcode.code128(),
            data: data.barcode,
            drawText: false,
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
          ),
        ),
        SizedBox(height: 2 * scale),
        Text(
          data.barcode,
          maxLines: 1,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _ink,
            fontSize: layout.codeFontSize * scale,
            height: _lineHeight,
          ),
        ),
      ],
    );
  }
}
