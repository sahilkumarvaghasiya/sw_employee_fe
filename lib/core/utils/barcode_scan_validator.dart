import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Preset tuning for different barcode scanning contexts.
enum BarcodeScanProfileKind {
  billing,
  stockEntry,
}

/// Configuration bundle for a barcode scanning context.
class BarcodeScanProfile {
  const BarcodeScanProfile({
    required this.kind,
    required this.formats,
    required this.requiredConsecutiveReads,
    required this.maxGapBetweenReads,
    required this.minBarcodeHeightRatio,
    required this.scanWindowWidthFactor,
    required this.scanWindowHeightFactor,
    required this.detectionSpeed,
    required this.detectionTimeoutMs,
    this.enableSecondaryDecode = false,
    this.returnImage = false,
  });

  final BarcodeScanProfileKind kind;
  final List<BarcodeFormat> formats;
  final int requiredConsecutiveReads;
  final Duration maxGapBetweenReads;
  final double minBarcodeHeightRatio;
  final double scanWindowWidthFactor;
  final double scanWindowHeightFactor;
  final DetectionSpeed detectionSpeed;
  final int detectionTimeoutMs;
  final bool enableSecondaryDecode;
  final bool returnImage;

  static const billing = BarcodeScanProfile(
    kind: BarcodeScanProfileKind.billing,
    formats: [BarcodeFormat.code128],
    requiredConsecutiveReads: 3,
    maxGapBetweenReads: Duration(milliseconds: 900),
    minBarcodeHeightRatio: 0.06,
    scanWindowWidthFactor: 0.88,
    scanWindowHeightFactor: 0.38,
    detectionSpeed: DetectionSpeed.normal,
    detectionTimeoutMs: 300,
  );

  static BarcodeScanProfile get stockEntry {
    return BarcodeScanProfile(
      kind: BarcodeScanProfileKind.stockEntry,
      formats: const [
        BarcodeFormat.code128,
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.upcA,
        BarcodeFormat.code39,
        BarcodeFormat.itf,
        BarcodeFormat.codabar,
      ],
      requiredConsecutiveReads: 1,
      maxGapBetweenReads: const Duration(milliseconds: 1200),
      minBarcodeHeightRatio: 0.02,
      scanWindowWidthFactor: 0.92,
      scanWindowHeightFactor: kIsWeb ? 0.5 : 0.42,
      detectionSpeed: DetectionSpeed.normal,
      detectionTimeoutMs: kIsWeb ? 200 : 300,
      enableSecondaryDecode: false,
      returnImage: false,
    );
  }

  bool get isStockEntry => kind == BarcodeScanProfileKind.stockEntry;

  List<String> get webScanHints => const [
        'Tilt the label to remove glare',
        'Move closer until the barcode fills the frame',
        'Hold steady for about one second',
        'Rotate the label upright if needed',
      ];
}

/// Legacy shared defaults kept for backward compatibility.
abstract final class BarcodeScanSettings {
  static List<BarcodeFormat> get supportedFormats =>
      BarcodeScanProfile.billing.formats;

  static int get requiredConsecutiveReads =>
      BarcodeScanProfile.billing.requiredConsecutiveReads;

  static Duration get maxGapBetweenReads =>
      BarcodeScanProfile.billing.maxGapBetweenReads;

  static double get minBarcodeHeightRatio =>
      BarcodeScanProfile.billing.minBarcodeHeightRatio;

  static double get scanWindowWidthFactor =>
      BarcodeScanProfile.billing.scanWindowWidthFactor;

  static double get scanWindowHeightFactor =>
      BarcodeScanProfile.billing.scanWindowHeightFactor;
}

/// Tracks stable barcode reads to reject partial or flickering detections.
class BarcodeScanValidator {
  BarcodeScanValidator({
    BarcodeScanProfile profile = BarcodeScanProfile.billing,
  })  : requiredReads = profile.requiredConsecutiveReads,
        maxGap = profile.maxGapBetweenReads;

  BarcodeScanValidator.legacy({
    int? requiredReads,
    Duration? maxGap,
  })  : requiredReads =
            requiredReads ?? BarcodeScanSettings.requiredConsecutiveReads,
        maxGap = maxGap ?? BarcodeScanSettings.maxGapBetweenReads;

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
  BarcodeScanProfile profile = BarcodeScanProfile.billing,
}) {
  if (barcodes.isEmpty) return null;

  Barcode? best;
  var bestScore = -1.0;

  for (final barcode in barcodes) {
    final value = barcode.rawValue?.trim();
    if (value == null || value.isEmpty) continue;

    if (!_isSupportedFormat(barcode.format, profile)) continue;
    if (!isBarcodeLargeEnough(barcode, layoutSize, profile)) continue;
    if (scanWindow != null &&
        !isBarcodeInScanWindow(barcode, scanWindow, profile)) {
      continue;
    }
    if (profile.isStockEntry && !isLikelyStockBarcodeValue(value)) continue;

    final score = _barcodeScore(barcode, layoutSize, profile) +
        stockBarcodeValueScore(value);
    if (score > bestScore) {
      bestScore = score;
      best = barcode;
    }
  }

  return best;
}

bool _isSupportedFormat(BarcodeFormat format, BarcodeScanProfile profile) {
  if (format == BarcodeFormat.unknown) {
    // Web / some platforms may not report format reliably.
    return true;
  }
  return profile.formats.contains(format);
}

bool isBarcodeLargeEnough(
  Barcode barcode,
  Size layoutSize, [
  BarcodeScanProfile profile = BarcodeScanProfile.billing,
]) {
  if (layoutSize.height <= 0) return true;

  final height = _barcodeHeight(barcode, layoutSize);
  if (height <= 0) {
    // Corners/size unavailable — do not reject (common on web).
    return true;
  }

  return height / layoutSize.height >= profile.minBarcodeHeightRatio;
}

bool isBarcodeInScanWindow(
  Barcode barcode,
  Rect scanWindow, [
  BarcodeScanProfile profile = BarcodeScanProfile.billing,
]) {
  final corners = barcode.corners;
  if (corners.isEmpty) return true;

  // Stock entry uses the scan window as a visual guide only.
  if (profile.isStockEntry) {
    return true;
  }

  var sumX = 0.0;
  var sumY = 0.0;
  for (final corner in corners) {
    sumX += corner.dx;
    sumY += corner.dy;
  }

  final center = Offset(sumX / corners.length, sumY / corners.length);
  return scanWindow.contains(center);
}

/// Normalizes a scanned value for stock entry before saving.
String normalizeStockBarcodeValue(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return trimmed;

  final compact = trimmed.replaceAll(RegExp(r'\s+'), '');
  if (RegExp(r'^\d{6,14}$').hasMatch(compact)) {
    return compact;
  }

  return trimmed.replaceAll(RegExp(r'\s+'), ' ').trim().toUpperCase();
}

bool isLikelyStockBarcodeValue(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed.length > 100) return false;

  final lower = trimmed.toLowerCase();
  if (lower.contains('mrp') ||
      lower.contains('cust') ||
      lower.contains('care') ||
      lower.contains('incl') ||
      lower.contains('tax')) {
    return false;
  }

  if (trimmed.contains('.') || trimmed.contains(',') || trimmed.contains('+')) {
    return false;
  }

  final compact = trimmed.replaceAll(' ', '');
  if (RegExp(r'^\d{6,14}$').hasMatch(compact)) {
    if (RegExp(r'^[6-9]\d{9}$').hasMatch(compact)) return false;
    return true;
  }

  return RegExp(r'^[A-Z][A-Z0-9\s\-]{3,14}$', caseSensitive: false)
      .hasMatch(trimmed);
}

int stockBarcodeValueScore(String value) {
  final compact = value.replaceAll(' ', '');
  var score = 0;

  if (RegExp(r'^\d{6,14}$').hasMatch(compact)) {
    score += 100;
    final len = compact.length;
    if (len >= 8 && len <= 10) score += 30;
    if (compact.startsWith('0')) score += 10;
  }

  if (RegExp(r'^[A-Z][A-Z0-9\s\-]{3,14}$', caseSensitive: false)
      .hasMatch(value)) {
    score += 80;
  }

  return score;
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

double _barcodeScore(
  Barcode barcode,
  Size layoutSize,
  BarcodeScanProfile profile,
) {
  final heightScore = _barcodeHeight(barcode, layoutSize);
  final widthScore = barcode.size.width > 0 ? barcode.size.width : heightScore;

  var formatBonus = 0.0;
  if (profile.formats.contains(barcode.format)) {
    formatBonus = 1000;
  }
  if (barcode.format == BarcodeFormat.code128) {
    formatBonus += 250;
  }

  return formatBonus + heightScore * 2 + widthScore;
}

Rect computeBarcodeScanWindow(
  Size layoutSize, [
  BarcodeScanProfile profile = BarcodeScanProfile.billing,
]) {
  final width = layoutSize.width * profile.scanWindowWidthFactor;
  final height = layoutSize.height * profile.scanWindowHeightFactor;

  return Rect.fromCenter(
    center: layoutSize.center(Offset.zero),
    width: width.clamp(0, layoutSize.width),
    height: height.clamp(0, layoutSize.height),
  );
}

MobileScannerController createBarcodeScannerController({
  bool autoStart = false,
  BarcodeScanProfile profile = BarcodeScanProfile.billing,
}) {
  return MobileScannerController(
    autoStart: autoStart,
    formats: profile.formats,
    detectionSpeed: profile.detectionSpeed,
    detectionTimeoutMs: profile.detectionTimeoutMs,
    returnImage: profile.returnImage,
  );
}
