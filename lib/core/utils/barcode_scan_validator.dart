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
      requiredConsecutiveReads: 2,
      maxGapBetweenReads: const Duration(milliseconds: 1400),
      minBarcodeHeightRatio: 0.006,
      scanWindowWidthFactor: 0.88,
      scanWindowHeightFactor: kIsWeb ? 0.62 : 0.58,
      detectionSpeed: DetectionSpeed.unrestricted,
      detectionTimeoutMs: kIsWeb ? 200 : 300,
      enableSecondaryDecode: false,
      returnImage: false,
    );
  }

  bool get isStockEntry => kind == BarcodeScanProfileKind.stockEntry;

  List<String> get webScanHints => const [
        'Horizontal or vertical barcode — any angle works',
        'Tilt the label to remove glare',
        'Move closer until the barcode fills the frame',
        'Hold steady for about one second',
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
    if (profile.isStockEntry) {
      final normalized = normalizeStockBarcodeValue(value);
      if (!isStrongStockBarcodeRead(normalized, barcode.format)) continue;
    }

    final scoreValue =
        profile.isStockEntry ? normalizeStockBarcodeValue(value) : value;
    final score = _barcodeScore(barcode, layoutSize, profile) +
        stockBarcodeValueScore(scoreValue, format: barcode.format);
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
  if (layoutSize.shortestSide <= 0) return true;

  final extent = _barcodeExtent(barcode);
  if (extent <= 0) {
    // Corners/size unavailable — do not reject (common on web).
    return true;
  }

  // Use the longest barcode edge so vertical (rotated) labels are not rejected.
  return extent / layoutSize.shortestSide >= profile.minBarcodeHeightRatio;
}

/// Picks the best stock barcode value from a camera frame.
String? pickBestStockBarcodeValue(
  List<Barcode> barcodes, {
  required Size layoutSize,
}) {
  final barcode = pickBestBarcode(
    barcodes,
    layoutSize: layoutSize,
    profile: BarcodeScanProfile.stockEntry,
  );

  final raw = barcode?.rawValue?.trim();
  if (raw == null || raw.isEmpty) return null;

  final normalized = normalizeStockBarcodeValue(raw);
  if (normalized.isEmpty) return null;
  if (!isStrongStockBarcodeRead(normalized, barcode!.format)) return null;

  return normalized;
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

bool isKnownStockBarcodeFormat(BarcodeFormat format) {
  return format != BarcodeFormat.unknown && format != BarcodeFormat.qrCode;
}

bool isLikelyStockBarcodeValue(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed.length > 100) return false;

  final lower = trimmed.toLowerCase();
  if (lower.contains('mrp') ||
      lower.contains('cust') ||
      lower.contains('care') ||
      lower.contains('incl') ||
      lower.contains('tax') ||
      lower.contains('http')) {
    return false;
  }

  if (trimmed.contains('.') || trimmed.contains(',') || trimmed.contains('+')) {
    return false;
  }

  // Product/style codes on hangtags (e.g. SFL-10465) are not stock barcodes.
  if (RegExp(r'^[A-Z]{2,5}-\d{3,8}$', caseSensitive: false).hasMatch(trimmed)) {
    return false;
  }

  final compact = trimmed.replaceAll(' ', '');
  if (RegExp(r'^\d+$').hasMatch(compact)) {
    // Numeric vendor barcodes are typically 8-14 digits.
    if (compact.length < 8 || compact.length > 14) return false;
    // Reject Indian mobile numbers often printed on labels.
    if (RegExp(r'^[6-9]\d{9}$').hasMatch(compact)) return false;
    // Reject repeated-digit noise (e.g. 00000000).
    if (RegExp(r'^(\d)\1{5,}$').hasMatch(compact)) return false;
    return true;
  }

  return RegExp(r'^[A-Z][A-Z0-9\s\-]{3,14}$', caseSensitive: false)
      .hasMatch(trimmed);
}

int stockBarcodeValueScore(String value, {BarcodeFormat? format}) {
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

  if (format != null) {
    if (format == BarcodeFormat.code128) score += 40;
    if (format == BarcodeFormat.code39) score += 35;
    if (format == BarcodeFormat.ean13 || format == BarcodeFormat.ean8) {
      score += 30;
    }
    if (format == BarcodeFormat.upcA) score += 30;
    if (format == BarcodeFormat.unknown) score -= 50;
  }

  return score;
}

/// Whether a camera read is strong enough to count toward acceptance.
bool isStrongStockBarcodeRead(String value, BarcodeFormat format) {
  if (!isLikelyStockBarcodeValue(value)) return false;

  if (isKnownStockBarcodeFormat(format)) {
    return true;
  }

  // Unknown format: only trust well-shaped numeric vendor codes.
  final compact = value.replaceAll(' ', '');
  return RegExp(r'^\d{8,14}$').hasMatch(compact);
}

Size _barcodeBoundingSize(Barcode barcode) {
  if (barcode.size.width > 0 && barcode.size.height > 0) {
    return barcode.size;
  }

  final corners = barcode.corners;
  if (corners.length < 2) return Size.zero;

  var minX = corners.first.dx;
  var maxX = corners.first.dx;
  var minY = corners.first.dy;
  var maxY = corners.first.dy;
  for (final corner in corners) {
    if (corner.dx < minX) minX = corner.dx;
    if (corner.dx > maxX) maxX = corner.dx;
    if (corner.dy < minY) minY = corner.dy;
    if (corner.dy > maxY) maxY = corner.dy;
  }

  return Size((maxX - minX).abs(), (maxY - minY).abs());
}

/// Longest edge of the barcode box — works for horizontal and vertical labels.
double _barcodeExtent(Barcode barcode) {
  final bounds = _barcodeBoundingSize(barcode);
  if (bounds.width <= 0 && bounds.height <= 0) return 0;
  return bounds.width > bounds.height ? bounds.width : bounds.height;
}

double _barcodeScore(
  Barcode barcode,
  Size layoutSize,
  BarcodeScanProfile profile,
) {
  final bounds = _barcodeBoundingSize(barcode);
  final extent = bounds.width > bounds.height ? bounds.width : bounds.height;
  final minEdge = bounds.width < bounds.height ? bounds.width : bounds.height;

  var formatBonus = 0.0;
  if (profile.formats.contains(barcode.format)) {
    formatBonus = 1000;
  }
  if (barcode.format == BarcodeFormat.code128) {
    formatBonus += 250;
  }

  // Prefer larger, clearer reads regardless of rotation.
  return formatBonus + extent * 2 + minEdge;
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
