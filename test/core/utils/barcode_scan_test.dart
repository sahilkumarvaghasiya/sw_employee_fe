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

    test('stock profile supports vendor 1D formats', () {
      final profile = BarcodeScanProfile.stockEntry;

      expect(profile.formats, contains(BarcodeFormat.ean13));
      expect(profile.requiredConsecutiveReads, 1);
      expect(profile.enableSecondaryDecode, isFalse);
    });
  });

  group('BarcodeScanValidator', () {
    test('billing profile still requires three identical reads', () {
      final validator = BarcodeScanValidator(profile: BarcodeScanProfile.billing);

      expect(validator.registerRead('123'), isNull);
      expect(validator.registerRead('123'), isNull);
      expect(validator.registerRead('123'), '123');
    });
  });

  group('Stock barcode extraction', () {
    test('extractStockBarcodeValue reads rawValue on first 1D barcode', () {
      const barcodes = [
        Barcode(
          rawValue: '2510077869',
          format: BarcodeFormat.code128,
        ),
      ];

      expect(extractStockBarcodeValue(barcodes), '2510077869');
    });

    test('extractStockBarcodeValue preserves leading zeros', () {
      const barcodes = [
        Barcode(
          rawValue: '01126087',
          format: BarcodeFormat.ean8,
        ),
      ];

      expect(extractStockBarcodeValue(barcodes), '01126087');
    });

    test('extractStockBarcodeValue accepts alphanumeric Code39', () {
      const barcodes = [
        Barcode(
          rawValue: 'R R33194',
          format: BarcodeFormat.code39,
        ),
      ];

      expect(extractStockBarcodeValue(barcodes), 'R R33194');
    });

    test('extractStockBarcodeValue skips QR codes', () {
      const barcodes = [
        Barcode(
          rawValue: '2510077869',
          format: BarcodeFormat.qrCode,
        ),
        Barcode(
          rawValue: '2510077869',
          format: BarcodeFormat.code128,
        ),
      ];

      expect(extractStockBarcodeValue(barcodes), '2510077869');
    });

    test('normalizeStockBarcodeValue preserves leading zeros', () {
      expect(normalizeStockBarcodeValue(' 01126087 '), '01126087');
      expect(normalizeStockBarcodeValue('R R33194'), 'R R33194');
    });
  });
}
