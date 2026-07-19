import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:sw_billing_employee_fe/core/utils/barcode_scan_validator.dart';

void main() {
  group('BarcodeScanProfile', () {
    test('billing profile matches stock robust 1D settings', () {
      const profile = BarcodeScanProfile.billing;

      expect(profile.formats, BarcodeScanProfile.stockEntry1dFormats);
      expect(profile.requiredConsecutiveReads, 2);
      expect(profile.scanWindowCenterYFactor, 0.58);
      expect(profile.minBarcodeHeightRatio, 0.0);
      expect(profile.detectionSpeed, DetectionSpeed.unrestricted);
      expect(profile.detectionTimeoutMs, 300);
      expect(profile.enableSecondaryDecode, isFalse);
      expect(profile.usesRobust1dPipeline, isTrue);
    });

    test('billing scan window is lower for hang-tag barcodes', () {
      const layoutSize = Size(400, 800);
      final window = computeBarcodeScanWindow(
        layoutSize,
        BarcodeScanProfile.billing,
      );

      expect(window.center.dy, closeTo(800 * 0.58, 0.01));
      expect(window.center.dy, greaterThan(layoutSize.height / 2));
    });

    test('stock profile supports every mobile_scanner 1D format', () {
      final profile = BarcodeScanProfile.stockEntry;

      expect(profile.formats, BarcodeScanProfile.stockEntry1dFormats);
      expect(profile.formats, hasLength(9));
      expect(profile.formats, containsAll(const [
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.code93,
        BarcodeFormat.codabar,
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.itf,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
      ]));
      expect(profile.formats, isNot(contains(BarcodeFormat.qrCode)));
      expect(profile.requiredConsecutiveReads, 2);
      expect(profile.usesRobust1dPipeline, isTrue);
    });

    test('stock scan window is lower for hang-tag barcodes', () {
      const layoutSize = Size(400, 800);
      final window = computeBarcodeScanWindow(
        layoutSize,
        BarcodeScanProfile.stockEntry,
      );

      expect(window.center.dy, closeTo(800 * 0.58, 0.01));
      expect(window.center.dy, greaterThan(layoutSize.height / 2));
    });
  });

  group('BarcodeScanValidator', () {
    test('billing profile accepts after two identical reads', () {
      final validator =
          BarcodeScanValidator(profile: BarcodeScanProfile.billing);

      expect(validator.registerRead('123'), isNull);
      expect(validator.registerRead('123'), '123');
    });

    test('billing profile still accepts second read after a long pause', () {
      final validator = BarcodeScanValidator(
        profile: BarcodeScanProfile.billing,
      );

      expect(validator.registerRead('123'), isNull);
      expect(validator.registerRead('456'), isNull);
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

    test('accepts every supported 1D format', () {
      const samples = <BarcodeFormat, String>{
        BarcodeFormat.code128: 'ABC123456',
        BarcodeFormat.code39: 'R R33194',
        BarcodeFormat.code93: 'CODE93X',
        BarcodeFormat.codabar: 'A40156B',
        BarcodeFormat.ean13: '5901234123457',
        BarcodeFormat.ean8: '01126087',
        BarcodeFormat.itf: '4021345678',
        BarcodeFormat.upcA: '012345678905',
        BarcodeFormat.upcE: '01234565',
      };

      for (final entry in samples.entries) {
        expect(
          isSupportedStock1dBarcodeFormat(entry.key),
          isTrue,
          reason: '${entry.key} should be supported',
        );
        expect(
          pickStockBarcodeValue([
            Barcode(rawValue: entry.value, format: entry.key),
          ]),
          normalizeStockBarcodeValue(entry.value),
          reason: '${entry.key} should decode ${entry.value}',
        );
      }
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
            Offset(160, 400),
            Offset(240, 400),
            Offset(240, 440),
            Offset(160, 440),
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

    test('accepts vertical 1D barcode overlapping the frame', () {
      const layoutSize = Size(400, 800);
      final scanWindow = computeBarcodeScanWindow(
        layoutSize,
        BarcodeScanProfile.stockEntry,
      );
      const barcodes = [
        Barcode(
          rawValue: '2510077869',
          format: BarcodeFormat.code128,
          corners: [
            Offset(190, 380),
            Offset(210, 380),
            Offset(210, 520),
            Offset(190, 520),
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

    test('preserves leading zeros for EAN-8 hang tags', () {
      const barcodes = [
        Barcode(
          rawValue: '01126087',
          format: BarcodeFormat.ean8,
        ),
      ];

      expect(pickStockBarcodeValue(barcodes), '01126087');
    });

    test('accepts known 1D read without position data (small web barcodes)', () {
      const layoutSize = Size(400, 800);
      final scanWindow = computeBarcodeScanWindow(
        layoutSize,
        BarcodeScanProfile.stockEntry,
      );
      const barcodes = [
        Barcode(
          rawValue: '9892749192',
          format: BarcodeFormat.code128,
        ),
      ];

      expect(
        pickStockBarcodeValue(
          barcodes,
          layoutSize: layoutSize,
          scanWindow: scanWindow,
        ),
        '9892749192',
      );
    });

    test('falls back to expanded frame for slightly misaligned small barcode', () {
      const layoutSize = Size(400, 800);
      final scanWindow = computeBarcodeScanWindow(
        layoutSize,
        BarcodeScanProfile.stockEntry,
      );
      const barcodes = [
        Barcode(
          rawValue: '9892749192',
          format: BarcodeFormat.ean13,
          corners: [
            Offset(40, 520),
            Offset(360, 520),
            Offset(360, 536),
            Offset(40, 536),
          ],
        ),
      ];

      expect(
        pickStockBarcodeValue(
          barcodes,
          layoutSize: layoutSize,
          scanWindow: scanWindow,
        ),
        '9892749192',
      );
    });

    test('uses full-frame fallback when exactly one known 1D is detected', () {
      const barcodes = [
        Barcode(
          rawValue: '3061',
          format: BarcodeFormat.code128,
        ),
      ];

      expect(pickStockBarcodeValue(barcodes), '3061');
    });

    test('supports long numeric Code128 values', () {
      const value = '12345678901234567890';
      expect(
        pickStockBarcodeValue(const [
          Barcode(rawValue: value, format: BarcodeFormat.code128),
        ]),
        value,
      );
    });

    test('rejects scanner garbage misread 12345678 on weak reads', () {
      const barcodes = [
        Barcode(
          rawValue: '12345678',
          format: BarcodeFormat.code128,
        ),
      ];

      expect(pickStockBarcodeValue(barcodes), isNull);
      expect(isSuspiciousStockBarcodeMisread('12345678'), isTrue);
      expect(
        isSuspiciousStockBarcodeMisread('12345678', confidentRead: true),
        isFalse,
      );
    });

    test('accepts real 12345678 when decode is confident', () {
      const layoutSize = Size(400, 800);
      final scanWindow = computeBarcodeScanWindow(
        layoutSize,
        BarcodeScanProfile.stockEntry,
      );
      const barcodes = [
        Barcode(
          rawValue: '12345678',
          format: BarcodeFormat.code128,
          corners: [
            Offset(160, 400),
            Offset(240, 400),
            Offset(240, 430),
            Offset(160, 430),
          ],
        ),
      ];

      expect(
        pickStockBarcodeValue(
          barcodes,
          layoutSize: layoutSize,
          scanWindow: scanWindow,
        ),
        '12345678',
      );
    });

    test('rejects ascending digit sequence misreads on weak reads', () {
      expect(isSuspiciousStockBarcodeMisread('1234567890'), isTrue);
      expect(
        isSuspiciousStockBarcodeMisread('1234567890', confidentRead: true),
        isFalse,
      );
      expect(isSuspiciousStockBarcodeMisread('2510077869'), isFalse);
    });

    test('normalizeStockBarcodeValue preserves leading zeros', () {
      expect(normalizeStockBarcodeValue(' 01126087 '), '01126087');
      expect(normalizeStockBarcodeValue('R R33194'), 'R R33194');
    });
  });

  group('billing robust picker parity', () {
    test('billing accepts non-Code128 1D formats via stock picker', () {
      const layoutSize = Size(400, 800);
      final scanWindow = computeBarcodeScanWindow(
        layoutSize,
        BarcodeScanProfile.billing,
      );
      const barcodes = [
        Barcode(
          rawValue: '2510077869',
          format: BarcodeFormat.ean13,
        ),
        Barcode(
          rawValue: 'BILLING123',
          format: BarcodeFormat.code128,
        ),
      ];

      // Prefer known 1D in frame; both valid — larger/known score wins.
      final picked = pickStockBarcodeValue(
        barcodes,
        layoutSize: layoutSize,
        scanWindow: scanWindow,
      );

      expect(picked, isNotNull);
      expect(
        ['2510077869', 'BILLING123'],
        contains(picked),
      );
    });

    test('billing profile formats include EAN and UPC like stock', () {
      expect(
        BarcodeScanProfile.billing.formats,
        containsAll([
          BarcodeFormat.ean13,
          BarcodeFormat.ean8,
          BarcodeFormat.upcA,
          BarcodeFormat.code39,
        ]),
      );
      expect(
        BarcodeScanProfile.billing.formats,
        BarcodeScanProfile.stockEntry1dFormats,
      );
    });
  });
}
