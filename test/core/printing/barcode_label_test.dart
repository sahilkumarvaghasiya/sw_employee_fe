import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';

import 'package:sw_billing_employee_fe/core/printing/barcode_label_builder.dart';
import 'package:sw_billing_employee_fe/core/printing/barcode_label_data.dart';
import 'package:sw_billing_employee_fe/core/printing/barcode_label_fonts.dart';
import 'package:sw_billing_employee_fe/core/printing/barcode_label_layout.dart';
import 'package:sw_billing_employee_fe/core/widgets/barcode_label_preview.dart';

/// Worst case a real screen can produce: a long name, three subtitle lines
/// (company + size + colour from the product detail screen) and a multi-price
/// string from a grouped stock entry.
const _worstCase = BarcodeLabelData(
  itemName: 'PREMIUM COTTON ROUND NECK T-SHIRT',
  barcode: '890123456',
  price: '₹499.00 / ₹599.00',
  subtitleLines: <String>[
    'Superwear Textiles Pvt Ltd',
    'Size: S, M, L, XL',
    'Colour: Navy Blue, Maroon',
  ],
);

void main() {
  group('BarcodeLabelData', () {
    test('folds extra subtitle lines into the last permitted line', () {
      final lines = _worstCase.cappedSubtitleLines(2);

      expect(lines, hasLength(2));
      expect(lines.first, 'Superwear Textiles Pvt Ltd');
      expect(lines.last, 'Size: S, M, L, XL · Colour: Navy Blue, Maroon');
    });

    test('keeps every line when it is already within the cap', () {
      expect(_worstCase.cappedSubtitleLines(5), hasLength(3));
    });

    test('drops subtitles entirely when the stock has no room', () {
      expect(_worstCase.cappedSubtitleLines(0), isEmpty);
    });

    test('mergedName strips size and colour prefixes', () {
      const data = BarcodeLabelData(
        itemName: 'T-SHIRT',
        barcode: '890123456',
        subtitleLines: <String>['Size: M', 'Colour: Red'],
      );

      expect(data.mergedName, 'T-SHIRT · M · Red');
    });
  });

  group('BarcodeLabelBuilder', () {
    for (final size in BarcodeLabelSize.values) {
      test('builds a single ${size.label} page', () async {
        final document = const BarcodeLabelBuilder().buildDocument(
          data: _worstCase,
          layout: BarcodeLabelLayout.forSize(size),
        );

        final bytes = await document.save();
        expect(bytes, isNotEmpty);
        expect(document.document.pdfPageList.pages, hasLength(1));
      });
    }

    testWidgets('embeds a font that carries the rupee glyph', (tester) async {
      final fonts = await BarcodeLabelFonts.load();
      expect(
        fonts,
        isNotNull,
        reason: 'Roboto must be bundled or ₹ prints as a box',
      );

      // The built-in PDF fonts are WinAnsi and have no ₹ at all. Assert the
      // bundled font actually maps U+20B9 rather than trusting the filename.
      const rupee = 0x20B9;
      for (final asset in <String>[
        'assets/fonts/Roboto-Regular.ttf',
        'assets/fonts/Roboto-Bold.ttf',
      ]) {
        final parser = TtfParser(await rootBundle.load(asset));
        expect(
          parser.charToGlyphIndexMap.containsKey(rupee),
          isTrue,
          reason: '$asset has no glyph for ₹ (U+20B9)',
        );
      }

      final bytes = await const BarcodeLabelBuilder()
          .buildDocument(data: _worstCase, fonts: fonts)
          .save();
      expect(bytes, isNotEmpty);
    });
  });

  group('BarcodeLabelPreview', () {
    // Narrow phone through to a desktop card, since every size scales off the
    // available width.
    for (final width in <double>[150, 260, 420]) {
      for (final size in BarcodeLabelSize.values) {
        testWidgets('renders ${size.label} at ${width}px without overflowing', (
          tester,
        ) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: width,
                    child: BarcodeLabelPreview(
                      data: _worstCase,
                      layout: BarcodeLabelLayout.forSize(size),
                    ),
                  ),
                ),
              ),
            ),
          );

          expect(tester.takeException(), isNull);
          expect(find.byType(BarcodeLabelPreview), findsOneWidget);
        });
      }
    }

    testWidgets('ignores the device text scale factor', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.5)),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 260,
                  child: BarcodeLabelPreview(data: _worstCase),
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
