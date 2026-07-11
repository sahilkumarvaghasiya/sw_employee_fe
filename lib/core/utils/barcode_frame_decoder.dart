import 'dart:typed_data';
import 'dart:ui';

import 'package:image/image.dart' as img;
import 'package:zxing_lib/common.dart';
import 'package:zxing_lib/multi.dart';
import 'package:zxing_lib/zxing.dart';

import 'barcode_scan_validator.dart';

/// Result of a secondary barcode decode attempt.
class BarcodeFrameDecodeResult {
  const BarcodeFrameDecodeResult({
    required this.value,
    required this.source,
  });

  final String value;
  final BarcodeFrameDecodeSource source;
}

enum BarcodeFrameDecodeSource {
  barcodePattern,
  labelText,
}

/// Decodes 1D barcodes from a camera frame using preprocessing retries.
class BarcodeFrameDecoder {
  const BarcodeFrameDecoder();

  static final RegExp _barcodeDigitPattern = RegExp(r'\d{6,14}');
  static final RegExp _barcodeTextPattern = RegExp(
    r'^[A-Z][A-Z0-9\s\-]{3,14}$',
    caseSensitive: false,
  );

  static const List<List<String>> _digitTemplates = [
    ['111', '101', '101', '101', '111'], // 0
    ['010', '110', '010', '010', '111'], // 1
    ['111', '001', '111', '100', '111'], // 2
    ['111', '001', '111', '001', '111'], // 3
    ['101', '101', '111', '001', '001'], // 4
    ['111', '100', '111', '001', '111'], // 5
    ['111', '100', '111', '101', '111'], // 6
    ['111', '001', '010', '010', '010'], // 7
    ['111', '101', '111', '101', '111'], // 8
    ['111', '101', '111', '001', '111'], // 9
  ];

  static const Map<String, List<String>> _letterTemplates = {
    'A': ['010', '101', '111', '101', '101', '111', '101'],
    'B': ['110', '101', '110', '101', '110', '101', '110'],
    'C': ['011', '100', '100', '100', '100', '100', '011'],
    'D': ['110', '101', '101', '101', '101', '101', '110'],
    'E': ['111', '100', '110', '100', '111', '100', '111'],
    'F': ['111', '100', '110', '100', '100', '100', '100'],
    'L': ['100', '100', '100', '100', '100', '100', '111'],
    'R': ['110', '101', '111', '101', '101', '101', '101'],
    'S': ['011', '100', '011', '001', '110', '100', '011'],
  };

  /// Attempts to decode a barcode from raw image bytes.
  ///
  /// [cropRect] is in normalized coordinates (0-1) relative to the image.
  /// Set [live] to true for faster camera-frame retries.
  Future<BarcodeFrameDecodeResult?> decodeFromImageBytes(
    Uint8List bytes, {
    Rect? cropRect,
    bool live = false,
  }) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    for (final variant in _buildVariants(decoded, cropRect: cropRect, live: live)) {
      final value = _decodeVariant(variant);
      final normalized = _normalizeDecodedValue(value);
      if (normalized != null) {
        return BarcodeFrameDecodeResult(
          value: normalized,
          source: BarcodeFrameDecodeSource.barcodePattern,
        );
      }
    }

    return null;
  }

  /// Reads a likely barcode number printed near the bars in the label.
  Future<BarcodeFrameDecodeResult?> decodePrintedNumberNearBarcode(
    Uint8List bytes, {
    Rect? cropRect,
    bool live = false,
  }) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    final searchAreas = <img.Image>[
      _stripBelowBarcodeBars(decoded),
      _expandCropForLabelText(decoded, cropRect),
      _vendorNumberStrip(decoded),
      if (!live) img.copyRotate(decoded, angle: 180),
      if (!live) _vendorNumberStrip(img.copyRotate(decoded, angle: 180)),
    ];

    String? best;
    var bestScore = 0;

    for (final area in searchAreas) {
      if (area.width < 8 || area.height < 8) continue;

      for (final variant in _buildVariants(area, cropRect: null, live: live)) {
        final zxingValue = _normalizeDecodedValue(_decodeVariant(variant));
        if (zxingValue != null) {
          final score = _scoreBarcodeCandidate(zxingValue, preferLabelText: true);
          if (score > bestScore) {
            bestScore = score;
            best = zxingValue;
          }
        }

        final digitValue = _extractDigitSequence(variant);
        if (digitValue != null) {
          final score = _scoreBarcodeCandidate(digitValue, preferLabelText: true);
          if (score > bestScore) {
            bestScore = score;
            best = digitValue;
          }
        }

        final textValue = _readPrintedBarcodeText(variant);
        if (textValue != null) {
          final score = _scoreBarcodeCandidate(textValue, preferLabelText: true);
          if (score > bestScore) {
            bestScore = score;
            best = textValue;
          }
        }
      }
    }

    if (best == null) return null;
    return BarcodeFrameDecodeResult(
      value: best,
      source: BarcodeFrameDecodeSource.labelText,
    );
  }

  List<img.Image> _buildVariants(
    img.Image source, {
    Rect? cropRect,
    bool live = false,
  }) {
    final cropRects = <Rect?>[cropRect];
    if (cropRect == null) {
      cropRects.addAll([
        const Rect.fromLTWH(0, 0.2, 1, 0.45),
        const Rect.fromLTWH(0, 0.35, 1, 0.3),
        if (!live) const Rect.fromLTWH(0, 0.1, 1, 0.55),
        if (!live) const Rect.fromLTWH(0.2, 0.25, 0.8, 0.3),
      ]);
    }

    final crops = <img.Image>[];
    for (final rect in cropRects) {
      crops.add(_cropImage(source, rect));
    }

    final variants = <img.Image>[];
    for (final cropped in crops) {
      if (cropped.width < 8 || cropped.height < 8) continue;

      final contrasted =
          img.adjustColor(cropped, contrast: 1.45, brightness: 0.03, gamma: 0.9);
      final sharpened = img.convolution(
        contrasted,
        filter: [0, -1, 0, -1, 5, -1, 0, -1, 0],
        div: 1,
      );
      final upscaled2 = img.copyResize(
        contrasted,
        width: (contrasted.width * 2).clamp(16, live ? 1600 : 2400),
      );

      variants.addAll([
        cropped,
        contrasted,
        sharpened,
        upscaled2,
        _invertImage(contrasted),
        if (!live) img.copyResize(
          contrasted,
          width: (contrasted.width * 3).clamp(16, 3200),
        ),
        if (!live) img.copyRotate(cropped, angle: 180),
        if (!live) img.copyRotate(contrasted, angle: 180),
        if (!live) _invertImage(upscaled2),
      ]);
    }

    return live ? variants.take(8).toList() : variants;
  }

  img.Image _stripBelowBarcodeBars(img.Image source) {
    final rowDensity = List<double>.filled(source.height, 0);
    for (var y = 0; y < source.height; y++) {
      var transitions = 0;
      var lastDark = false;
      for (var x = 0; x < source.width; x++) {
        final dark = source.getPixel(x, y).r < 120;
        if (x > 0 && dark != lastDark) transitions++;
        lastDark = dark;
      }
      rowDensity[y] = transitions / source.width;
    }

    var peakY = 0;
    var peakDensity = 0.0;
    for (var y = 0; y < source.height; y++) {
      if (rowDensity[y] > peakDensity) {
        peakDensity = rowDensity[y];
        peakY = y;
      }
    }

    final top = (peakY + source.height * 0.08).round().clamp(0, source.height - 1);
    final bottom =
        (peakY + source.height * 0.28).round().clamp(top + 1, source.height);

    return img.copyCrop(
      source,
      x: 0,
      y: top,
      width: source.width,
      height: bottom - top,
    );
  }

  img.Image _vendorNumberStrip(img.Image source) {
    final y = (source.height * 0.42).round().clamp(0, source.height - 1);
    final height = (source.height * 0.14).round().clamp(1, source.height - y);
    return img.copyCrop(
      source,
      x: 0,
      y: y,
      width: source.width,
      height: height,
    );
  }

  img.Image _expandCropForLabelText(img.Image source, Rect? cropRect) {
    final y = (cropRect == null ? 0 : (cropRect.top * source.height).round())
        .clamp(0, source.height - 1);
    final height = (cropRect == null
            ? source.height
            : (cropRect.height * source.height).round())
        .clamp(1, source.height - y);
    final x = (cropRect == null ? 0 : (cropRect.left * source.width).round())
        .clamp(0, source.width - 1);
    final width = (cropRect == null
            ? source.width
            : (cropRect.width * source.width).round())
        .clamp(1, source.width - x);

    final extraTop = (height * 0.45).round();
    final extraBottom = (height * 0.35).round();
    final top = (y - extraTop).clamp(0, source.height - 1);
    final bottom = (y + height + extraBottom).clamp(top + 1, source.height);
    final left = x.clamp(0, source.width - 1);
    final right = (x + width).clamp(left + 1, source.width);

    return img.copyCrop(
      source,
      x: left,
      y: top,
      width: right - left,
      height: bottom - top,
    );
  }

  img.Image _cropImage(img.Image source, Rect? cropRect) {
    if (cropRect == null) return source;

    final x = (cropRect.left * source.width).round().clamp(0, source.width - 1);
    final y = (cropRect.top * source.height).round().clamp(0, source.height - 1);
    final width =
        (cropRect.width * source.width).round().clamp(1, source.width - x);
    final height =
        (cropRect.height * source.height).round().clamp(1, source.height - y);

    return img.copyCrop(source, x: x, y: y, width: width, height: height);
  }

  img.Image _invertImage(img.Image source) {
    final inverted = source.clone();
    for (var y = 0; y < inverted.height; y++) {
      for (var x = 0; x < inverted.width; x++) {
        final pixel = inverted.getPixel(x, y);
        inverted.setPixel(
          x,
          y,
          img.ColorRgb8(
            255 - pixel.r.toInt(),
            255 - pixel.g.toInt(),
            255 - pixel.b.toInt(),
          ),
        );
      }
    }
    return inverted;
  }

  String? _decodeVariant(img.Image image) {
    final pixels = _toLuminance(image);
    final source = RGBLuminanceSource.orig(image.width, image.height, pixels);

    final readers = <BinaryBitmap>[
      BinaryBitmap(HybridBinarizer(source)),
      BinaryBitmap(GlobalHistogramBinarizer(source)),
    ];

    final zxingReader = GenericMultipleBarcodeReader(MultiFormatReader());
    for (final bitmap in readers) {
      try {
        final results = zxingReader.decodeMultiple(
          bitmap,
          const DecodeHint(
            tryHarder: true,
            alsoInverted: true,
          ),
        );

        for (final result in results) {
          final text = result.text.trim();
          if (text.isNotEmpty) {
            return text;
          }
        }
      } on NotFoundException {
        continue;
      }
    }

    return null;
  }

  String? _normalizeDecodedValue(String? value) {
    if (value == null) return null;
    final normalized = normalizeStockBarcodeValue(value);
    if (!isLikelyStockBarcodeValue(normalized)) return null;
    return normalized;
  }

  int _scoreBarcodeCandidate(String value, {required bool preferLabelText}) {
    final compact = value.replaceAll(' ', '');
    var score = 0;

    if (_barcodeDigitPattern.hasMatch(compact)) {
      score += 100;
      final len = compact.length;
      if (len >= 8 && len <= 10) score += 40;
      if (len == 8 || len == 10) score += 20;
    }

    if (_barcodeTextPattern.hasMatch(value.toUpperCase())) {
      score += 90;
      if (RegExp(r'[A-Z]').hasMatch(value) && RegExp(r'\d').hasMatch(value)) {
        score += 30;
      }
    }

    if (preferLabelText) score += 10;
    return score;
  }

  Uint8List _toLuminance(img.Image image) {
    final pixels = Uint8List(image.width * image.height);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toInt() & 0xff;
        final g = (pixel.g.toInt() << 1) & 0x1fe;
        final b = pixel.b.toInt();
        pixels[y * image.width + x] = ((r + g + b) ~/ 4);
      }
    }
    return pixels;
  }

  String? _extractDigitSequence(img.Image image) {
    final value = _decodeVariant(image);
    if (value != null) {
      final match = _barcodeDigitPattern.firstMatch(value.replaceAll(' ', ''));
      if (match != null) return match.group(0);
    }

    return _readPrintedDigits(image);
  }

  String? _readPrintedBarcodeText(img.Image image) {
    final upscaled = img.copyResize(
      image,
      width: (image.width * 3).round().clamp(120, 2400),
    );
    final gray = img.grayscale(upscaled);
    img.adjustColor(gray, contrast: 2.0, brightness: 0.05);
    final cleaned = img.gaussianBlur(gray, radius: 1);

    String? best;
    var bestScore = 0;

    for (final bandSource in [gray, cleaned]) {
      for (var bandHeight = 14; bandHeight <= 40; bandHeight += 8) {
        for (var y = 0; y <= bandSource.height - bandHeight; y += 6) {
          final band = img.copyCrop(
            bandSource,
            x: 0,
            y: y,
            width: bandSource.width,
            height: bandHeight,
          );

          final score = _textBandScore(band);
          if (score < 16) continue;

          final text = _recognizeBarcodeTextInBand(band);
          if (text == null) continue;

          final candidateScore = score + _scoreBarcodeCandidate(text, preferLabelText: true);
          if (candidateScore > bestScore) {
            bestScore = candidateScore;
            best = text;
          }
        }
      }
    }

    return best;
  }

  String? _readPrintedDigits(img.Image image) {
    final upscaled = img.copyResize(
      image,
      width: (image.width * 3).round().clamp(120, 2400),
    );
    final gray = img.grayscale(upscaled);
    img.adjustColor(gray, contrast: 2.0, brightness: 0.05);
    final cleaned = img.gaussianBlur(gray, radius: 1);

    String? best;
    var bestScore = 0;

    for (final bandSource in [gray, cleaned]) {
      for (var bandHeight = 14; bandHeight <= 40; bandHeight += 8) {
        for (var y = 0; y <= bandSource.height - bandHeight; y += 6) {
          final band = img.copyCrop(
            bandSource,
            x: 0,
            y: y,
            width: bandSource.width,
            height: bandHeight,
          );

          final score = _textBandScore(band);
          if (score < 16) continue;

          final digits = _recognizeDigitsInBand(band);
          if (digits == null || digits.length < 6) continue;

          final candidateScore = score + _scoreBarcodeCandidate(digits, preferLabelText: true);
          if (candidateScore > bestScore) {
            bestScore = candidateScore;
            best = digits;
          }
        }
      }
    }

    return best;
  }

  int _textBandScore(img.Image band) {
    var darkPixels = 0;
    var transitions = 0;
    var lastDark = false;

    for (var y = 0; y < band.height; y++) {
      for (var x = 0; x < band.width; x++) {
        final dark = band.getPixel(x, y).r < 120;
        if (dark) darkPixels++;
        if (x > 0) {
          final prevDark = band.getPixel(x - 1, y).r < 120;
          if (prevDark != dark) transitions++;
        }
        if (x == 0) {
          lastDark = dark;
        } else if (dark != lastDark) {
          lastDark = dark;
        }
      }
    }

    final total = band.width * band.height;
    final darkRatio = darkPixels / total;
    if (darkRatio < 0.04 || darkRatio > 0.45) return 0;

    final transitionDensity = transitions / total;
    if (transitionDensity > 0.35) return 0;

    return ((darkRatio * 100).round() + transitions ~/ 8);
  }

  String? _recognizeBarcodeTextInBand(img.Image band) {
    final columns = _segmentColumns(_binarizeBand(band));
    if (columns.length < 4) return null;

    final buffer = StringBuffer();
    var uncertain = 0;

    for (final column in columns) {
      if (column.width <= 1) {
        buffer.write(' ');
        continue;
      }

      final glyph = _matchDigit(column) ?? _matchLetter(column);
      if (glyph == null) {
        uncertain++;
        if (uncertain > 2) return null;
        continue;
      }
      buffer.write(glyph);
    }

    final raw = buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim().toUpperCase();
    if (raw.isEmpty) return null;
    if (!isLikelyStockBarcodeValue(raw)) return null;

    if (_barcodeDigitPattern.hasMatch(raw.replaceAll(' ', ''))) {
      return _barcodeDigitPattern.firstMatch(raw.replaceAll(' ', ''))!.group(0);
    }

    if (_barcodeTextPattern.hasMatch(raw)) {
      return raw;
    }

    return null;
  }

  String? _recognizeDigitsInBand(img.Image band) {
    final binary = _binarizeBand(band);
    final columns = _segmentColumns(binary);
    if (columns.length < 6) return null;

    for (final windowSize in [8, 9, 10, 11, 12, 13, 14]) {
      if (columns.length < windowSize) continue;

      for (var start = 0; start <= columns.length - windowSize; start++) {
        final window = columns.sublist(start, start + windowSize);
        final value = _recognizeDigitWindow(window);
        if (value != null && _barcodeDigitPattern.hasMatch(value)) {
          return value;
        }
      }
    }

    return _recognizeDigitWindow(columns);
  }

  img.Image _binarizeBand(img.Image band) {
    final binary = band.clone();
    for (var y = 0; y < binary.height; y++) {
      for (var x = 0; x < binary.width; x++) {
        final dark = binary.getPixel(x, y).r < 120;
        binary.setPixel(
          x,
          y,
          dark ? img.ColorRgb8(0, 0, 0) : img.ColorRgb8(255, 255, 255),
        );
      }
    }
    return binary;
  }

  String? _recognizeDigitWindow(List<img.Image> columns) {
    final buffer = StringBuffer();
    var uncertain = 0;

    for (final column in columns) {
      final digit = _matchDigit(column);
      if (digit == null) {
        uncertain++;
        if (uncertain > 3) return null;
        continue;
      }
      buffer.write(digit);
    }

    final value = buffer.toString();
    if (value.length < 6) return null;
    return _barcodeDigitPattern.hasMatch(value) ? value : null;
  }

  List<img.Image> _segmentColumns(img.Image band) {
    final projection = List<int>.filled(band.width, 0);
    for (var x = 0; x < band.width; x++) {
      for (var y = 0; y < band.height; y++) {
        if (band.getPixel(x, y).r < 128) {
          projection[x]++;
        }
      }
    }

    final segments = <List<int>>[];
    var start = -1;
    for (var x = 0; x < projection.length; x++) {
      final active = projection[x] > 0;
      if (active && start == -1) {
        start = x;
      } else if (!active && start != -1) {
        if (x - start >= 2) {
          segments.add([start, x]);
        }
        start = -1;
      }
    }
    if (start != -1 && band.width - start >= 2) {
      segments.add([start, band.width]);
    }

    return segments
        .map(
          (range) => img.copyCrop(
            band,
            x: range[0],
            y: 0,
            width: range[1] - range[0],
            height: band.height,
          ),
        )
        .where((segment) => segment.width >= 2)
        .toList();
  }

  String? _matchDigit(img.Image segment) {
    final normalized = img.copyResize(segment, width: 5, height: 7);
    final pattern = <String>[];
    for (var y = 0; y < 7; y++) {
      final row = StringBuffer();
      for (var x = 0; x < 5; x++) {
        row.write(normalized.getPixel(x, y).r < 128 ? '1' : '0');
      }
      pattern.add(row.toString());
    }

    var bestDigit = -1;
    var bestDistance = 999;
    for (var i = 0; i < _digitTemplates.length; i++) {
      final expanded = _expandTemplate(_digitTemplates[i]);
      final distance = _patternDistance(pattern, expanded);
      if (distance < bestDistance) {
        bestDistance = distance;
        bestDigit = i;
      }
    }

    if (bestDigit == -1 || bestDistance > 14) return null;
    return '$bestDigit';
  }

  String? _matchLetter(img.Image segment) {
    final normalized = img.copyResize(segment, width: 5, height: 7);
    final pattern = <String>[];
    for (var y = 0; y < 7; y++) {
      final row = StringBuffer();
      for (var x = 0; x < 5; x++) {
        row.write(normalized.getPixel(x, y).r < 128 ? '1' : '0');
      }
      pattern.add(row.toString());
    }

    String? bestLetter;
    var bestDistance = 999;
    for (final entry in _letterTemplates.entries) {
      final expanded = _expandTemplate(entry.value);
      final distance = _patternDistance(pattern, expanded);
      if (distance < bestDistance) {
        bestDistance = distance;
        bestLetter = entry.key;
      }
    }

    if (bestLetter == null || bestDistance > 16) return null;
    return bestLetter;
  }

  List<String> _expandTemplate(List<String> template) {
    return template
        .map(
          (row) => row
              .split('')
              .expand((cell) => [cell, cell])
              .join()
              .padRight(5, '0')
              .substring(0, 5),
        )
        .expand((row) => [row, row])
        .toList()
        .take(7)
        .toList();
  }

  int _patternDistance(List<String> a, List<String> b) {
    var distance = 0;
    for (var i = 0; i < a.length; i++) {
      for (var j = 0; j < a[i].length; j++) {
        if (a[i][j] != b[i][j]) distance++;
      }
    }
    return distance;
  }
}

/// Converts a layout [scanWindow] into normalized image crop coordinates.
Rect normalizedCropFromScanWindow(Rect scanWindow, Size layoutSize) {
  if (layoutSize.width <= 0 || layoutSize.height <= 0) {
    return const Rect.fromLTWH(0, 0, 1, 1);
  }

  return Rect.fromLTRB(
    (scanWindow.left / layoutSize.width).clamp(0, 1),
    (scanWindow.top / layoutSize.height).clamp(0, 1),
    (scanWindow.right / layoutSize.width).clamp(0, 1),
    (scanWindow.bottom / layoutSize.height).clamp(0, 1),
  );
}
