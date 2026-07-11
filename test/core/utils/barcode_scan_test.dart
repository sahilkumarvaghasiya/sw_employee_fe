import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:sw_billing_employee_fe/core/utils/barcode_scan_validator.dart';

void main() {
  group('BarcodeScanProfile', () {
    test('billing profile keeps strict Code128-only settings', () {
      const profile = BarcodeScanProfile.billing;

      expect(profile.formats, [BarcodeFormat.code128]);
      expect(profile.requiredConsecutiveReads, 3);
      expect(profile.detectionTimeoutMs, 300);
      expect(profile.enableSecondaryDecode, isFalse);
    });

    test('stock profile supports all common 1D formats', () {
      final profile = BarcodeScanProfile.stockEntry;

      expect(profile.formats, contains(BarcodeFormat.code93));
      expect(profile.formats, contains(BarcodeFormat.upcE));
      expect(profile.formats, isNot(contains(BarcodeFormat.qrCode)));
      expect(profile.requiredConsecutiveReads, 2);
    });
  });

  group('BarcodeScanValidator', () {
    test('billing profile still requires three identical reads', () {
      final validator = BarcodeScanValidator(profile: BarcodeScanProfile.billing);

      expect(validator.registerRead('123'), isNull);
      expect(validator.registerRead('123'), isNull);
      expect(validator.registerRead('123'), '123');
    });

    test('stock profile accepts after two identical reads', () {
      final validator =
          BarcodeScanValidator(profile: BarcodeScanProfile.stockEntry);

      expect(validator.registerRead('2510077869'), isNull);
      expect(validator.registerRead('2510077869'), '2510077869');
    });

    test('stock profile still accepts second read after a long pause', () {
      final validator =
          BarcodeScanValidator(profile: BarcodeScanProfile.stockEntry);

      expect(validator.registerRead('2510077869'), isNull);
      expect(validator.registerRead('01126087'), isNull);
      expect(validator.registerRead('2510077869'), isNull);
      expect(validator.registerRead('2510077869'), '2510077869');
    });
  });

  group('pickStockBarcodeValue', () {
    test('reads rawValue from a known 1D symbology', () {
      const barcodes = [
        Barcode(
          rawValue: '2510077869',
          format: BarcodeFormat.code128,
        ),
      ];

      expect(pickStockBarcodeValue(barcodes), '2510077869');
    });

    test('prefers largest known 1D barcode on crowded labels', () {
      const layoutSize = Size(400, 800);
      const barcodes = [
        Barcode(
          rawValue: '8320105110',
          format: BarcodeFormat.code128,
          size: Size(80, 12),
        ),
        Barcode(
          rawValue: '2510077869',
          format: BarcodeFormat.code128,
          size: Size(220, 36),
        ),
      ];

      expect(
        pickStockBarcodeValue(barcodes, layoutSize: layoutSize),
        '2510077869',
      );
    });

    test('ignores barcodes outside the scan frame', () {
      const layoutSize = Size(400, 800);
      final scanWindow = computeBarcodeScanWindow(
        layoutSize,
        BarcodeScanProfile.stockEntry,
      );
      const barcodes = [
        Barcode(
          rawValue: '8320105110',
          format: BarcodeFormat.code128,
          corners: [
            Offset(20, 40),
            Offset(120, 40),
            Offset(120, 60),
            Offset(20, 60),
          ],
        ),
        Barcode(
          rawValue: '2510077869',
          format: BarcodeFormat.code128,
          corners: [
            Offset(160, 360),
            Offset(240, 360),
            Offset(240, 400),
            Offset(160, 400),
          ],
        ),
      ];

      expect(
        pickStockBarcodeValue(
          barcodes,
          layoutSize: layoutSize,
          scanWindow: scanWindow,
        ),
        '2510077869',
      );
    });

    test('supports Code93 and UPC-E', () {
      expect(
        pickStockBarcodeValue(const [
          Barcode(rawValue: 'ABC123', format: BarcodeFormat.code93),
        ]),
        'ABC123',
      );
      expect(
        pickStockBarcodeValue(const [
          Barcode(rawValue: '01234565', format: BarcodeFormat.upcE),
        ]),
        '01234565',
      );
    });

    test('skips 2D symbologies', () {
      const barcodes = [
        Barcode(
          rawValue: 'wrong',
          format: BarcodeFormat.qrCode,
        ),
        Barcode(
          rawValue: '2510077869',
          format: BarcodeFormat.ean13,
        ),
      ];

      expect(pickStockBarcodeValue(barcodes), '2510077869');
    });

    test('preserves leading zeros', () {
      const barcodes = [
        Barcode(
          rawValue: '01126087',
          format: BarcodeFormat.ean8,
        ),
      ];

      expect(pickStockBarcodeValue(barcodes), '01126087');
    });

    test('normalizeStockBarcodeValue preserves leading zeros', () {
      expect(normalizeStockBarcodeValue(' 01126087 '), '01126087');
      expect(normalizeStockBarcodeValue('R R33194'), 'R R33194');
    });
  });
}
