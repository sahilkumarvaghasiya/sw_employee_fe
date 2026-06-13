import 'dart:ui';

import 'package:mobile_scanner/mobile_scanner.dart';

/// Shared tuning for barcode camera scanning.
abstract final class BarcodeScanSettings {
  static const List<BarcodeFormat> supportedFormats = [BarcodeFormat.code128];

  /// Number of identical consecutive reads required before accepting a scan.
  static const int requiredConsecutiveReads = 3;

  /// Max gap between consecutive reads before the counter resets.
  static const Duration maxGapBetweenReads = Duration(milliseconds: 900);

  /// Minimum barcode height as a fraction of the scanner layout height.
  static const double minBarcodeHeightRatio = 0.06;

  /// Scan window width as a fraction of layout width.
  static const double scanWindowWidthFactor = 0.88;

  /// Scan window height as a fraction of layout height.
  static const double scanWindowHeightFactor = 0.38;
}

/// Tracks stable barcode reads to reject partial or flickering detections.
class BarcodeScanValidator {
  BarcodeScanValidator({
    this.requiredReads = BarcodeScanSettings.requiredConsecutiveReads,
    this.maxGap = BarcodeScanSettings.maxGapBetweenReads,
  });

  final int requiredReads;
  final Duration maxGap;

  String? _lastCandidate;
  int _consecutiveCount = 0;
  DateTime? _lastReadAt;

  int get consecutiveCount => _consecutiveCount;
  int get requiredConsecutiveReads => requiredReads;
  String? get pendingValue => _consecutiveCount > 0 ? _lastCandidate : null;

  /// Registers a candidate read. Returns the value when stable enough to accept.
  String? registerRead(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      reset();
      return null;
    }

    final now = DateTime.now();
    final sameAsLast = _lastCandidate == normalized;
    final withinGap =
        _lastReadAt != null && now.difference(_lastReadAt!) <= maxGap;

    if (sameAsLast && withinGap) {
      _consecutiveCount++;
    } else {
      _lastCandidate = normalized;
      _consecutiveCount = 1;
    }

    _lastReadAt = now;

    if (_consecutiveCount >= requiredReads) {
      final accepted = normalized;
      reset();
      return accepted;
    }

    return null;
  }

  void reset() {
    _lastCandidate = null;
    _consecutiveCount = 0;
    _lastReadAt = null;
  }
}

/// Picks the best barcode candidate from a camera frame.
Barcode? pickBestBarcode(
  List<Barcode> barcodes, {
  required Size layoutSize,
  Rect? scanWindow,
}) {
  if (barcodes.isEmpty) return null;

  Barcode? best;
  var bestScore = -1.0;

  for (final barcode in barcodes) {
    final value = barcode.rawValue?.trim();
    if (value == null || value.isEmpty) continue;

    if (!_isSupportedFormat(barcode.format)) continue;
    if (!isBarcodeLargeEnough(barcode, layoutSize)) continue;
    if (scanWindow != null && !isBarcodeInScanWindow(barcode, scanWindow)) {
      continue;
    }

    final score = _barcodeScore(barcode, layoutSize);
    if (score > bestScore) {
      bestScore = score;
      best = barcode;
    }
  }

  return best;
}

bool _isSupportedFormat(BarcodeFormat format) {
  if (format == BarcodeFormat.unknown) {
    // Web / some platforms may not report format reliably.
    return true;
  }
  return BarcodeScanSettings.supportedFormats.contains(format);
}

bool isBarcodeLargeEnough(Barcode barcode, Size layoutSize) {
  if (layoutSize.height <= 0) return true;

  final height = _barcodeHeight(barcode, layoutSize);
  if (height <= 0) {
    // Corners/size unavailable — do not reject (common on web).
    return true;
  }

  return height / layoutSize.height >= BarcodeScanSettings.minBarcodeHeightRatio;
}

bool isBarcodeInScanWindow(Barcode barcode, Rect scanWindow) {
  final corners = barcode.corners;
  if (corners.isEmpty) return true;

  var sumX = 0.0;
  var sumY = 0.0;
  for (final corner in corners) {
    sumX += corner.dx;
    sumY += corner.dy;
  }

  final center = Offset(sumX / corners.length, sumY / corners.length);
  return scanWindow.contains(center);
}

double _barcodeHeight(Barcode barcode, Size layoutSize) {
  if (barcode.size.height > 0) {
    return barcode.size.height;
  }

  final corners = barcode.corners;
  if (corners.length < 2) return 0;

  var minY = corners.first.dy;
  var maxY = corners.first.dy;
  for (final corner in corners) {
    if (corner.dy < minY) minY = corner.dy;
    if (corner.dy > maxY) maxY = corner.dy;
  }

  return (maxY - minY).abs();
}

double _barcodeScore(Barcode barcode, Size layoutSize) {
  final heightScore = _barcodeHeight(barcode, layoutSize);
  final widthScore = barcode.size.width > 0 ? barcode.size.width : heightScore;

  var formatBonus = 0.0;
  if (barcode.format == BarcodeFormat.code128) {
    formatBonus = 1000;
  }

  return formatBonus + heightScore * 2 + widthScore;
}

Rect computeBarcodeScanWindow(Size layoutSize) {
  final width = layoutSize.width * BarcodeScanSettings.scanWindowWidthFactor;
  final height = layoutSize.height * BarcodeScanSettings.scanWindowHeightFactor;

  return Rect.fromCenter(
    center: layoutSize.center(Offset.zero),
    width: width.clamp(0, layoutSize.width),
    height: height.clamp(0, layoutSize.height),
  );
}

MobileScannerController createBarcodeScannerController({
  bool autoStart = false,
}) {
  return MobileScannerController(
    autoStart: autoStart,
    formats: BarcodeScanSettings.supportedFormats,
    detectionSpeed: DetectionSpeed.normal,
    detectionTimeoutMs: 300,
  );
}
