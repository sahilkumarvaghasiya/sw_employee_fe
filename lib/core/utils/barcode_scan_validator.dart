import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
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
    this.scanWindowCenterYFactor = 0.5,
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
  /// Vertical center of the scan frame, 0 = top, 1 = bottom. Hang-tag barcodes
  /// sit below tag center, so stock entry uses ~0.58.
  final double scanWindowCenterYFactor;
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

  static const stockEntry1dFormats = [
    BarcodeFormat.code128,
    BarcodeFormat.code39,
    BarcodeFormat.code93,
    BarcodeFormat.codabar,
    BarcodeFormat.ean13,
    BarcodeFormat.ean8,
    BarcodeFormat.itf,
    BarcodeFormat.upcA,
    BarcodeFormat.upcE,
  ];

  static BarcodeScanProfile get stockEntry {
    return BarcodeScanProfile(
      kind: BarcodeScanProfileKind.stockEntry,
      formats: stockEntry1dFormats,
      requiredConsecutiveReads: 2,
      maxGapBetweenReads: const Duration(milliseconds: 1200),
      minBarcodeHeightRatio: 0.0,
      scanWindowWidthFactor: 0.88,
      scanWindowHeightFactor: 0.24,
      scanWindowCenterYFactor: 0.58,
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
        maxGap = profile.maxGapBetweenReads,
        _forgiveReadGap = profile.isStockEntry;

  BarcodeScanValidator.legacy({
    int? requiredReads,
    Duration? maxGap,
    bool forgiveReadGap = false,
  })  : requiredReads =
            requiredReads ?? BarcodeScanSettings.requiredConsecutiveReads,
        maxGap = maxGap ?? BarcodeScanSettings.maxGapBetweenReads,
        _forgiveReadGap = forgiveReadGap;

  final int requiredReads;
  final Duration maxGap;
  final bool _forgiveReadGap;

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

    if (sameAsLast && (withinGap || _forgiveReadGap)) {
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

    final score = _barcodeScore(barcode, layoutSize, profile);
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

/// All 1D symbologies supported by [mobile_scanner] for stock entry.
/// 2D types (QR, DataMatrix, PDF417, Aztec) are intentionally excluded.
bool isSupportedStock1dBarcodeFormat(BarcodeFormat format) {
  return isStock1dBarcodeFormat(format);
}

/// True when [format] is a supported 1D stock barcode symbology.
bool isStock1dBarcodeFormat(BarcodeFormat format) {
  return BarcodeScanProfile.stockEntry1dFormats.contains(format);
}

/// True when [format] is a 2D symbology (not used for stock entry).
bool is2dBarcodeFormat(BarcodeFormat format) {
  return format == BarcodeFormat.qrCode ||
      format == BarcodeFormat.dataMatrix ||
      format == BarcodeFormat.pdf417 ||
      format == BarcodeFormat.aztec;
}

/// Picks the best 1D barcode inside [scanWindow]. Prefers a known symbology and
/// the largest barcode box so crowded labels do not return the wrong number.
String? pickStockBarcodeValue(
  List<Barcode> barcodes, {
  Size layoutSize = Size.zero,
  Size textureSize = Size.zero,
  Rect? scanWindow,
}) {
  Barcode? best;
  var bestScore = -1.0;

  var validKnownCount = 0;
  for (final barcode in barcodes) {
    final raw = barcode.rawValue?.trim();
    if (raw == null || raw.isEmpty) continue;
    if (is2dBarcodeFormat(barcode.format)) continue;
    if (!isStock1dBarcodeFormat(barcode.format) &&
        barcode.format != BarcodeFormat.unknown) {
      continue;
    }
    final normalized = normalizeStockBarcodeValue(raw);
    if (normalized.isEmpty || normalized.length > 100) continue;
    if (isStock1dBarcodeFormat(barcode.format)) validKnownCount++;
  }
  final relaxWindowFilter = validKnownCount == 1;

  for (final barcode in barcodes) {
    final raw = barcode.rawValue?.trim();
    if (raw == null || raw.isEmpty) continue;
    if (is2dBarcodeFormat(barcode.format)) continue;

    final knownFormat = isStock1dBarcodeFormat(barcode.format);
    if (!knownFormat && barcode.format != BarcodeFormat.unknown) continue;

    if (scanWindow != null &&
        !isBarcodeInsideScanWindow(
          barcode,
          scanWindow,
          layoutSize: layoutSize,
          textureSize: textureSize,
          allowWithoutPosition:
              barcodes.length == 1 || relaxWindowFilter,
        )) {
      continue;
    }

    final normalized = normalizeStockBarcodeValue(raw);
    if (normalized.isEmpty || normalized.length > 100) continue;

    // Known 1D symbology: trust the library decoder on [rawValue].
    if (!knownFormat && !isPlausibleStockBarcodePayload(normalized)) continue;

    var score = knownFormat ? 100000.0 : 1000.0;
    score += _barcodeExtent(barcode) * 2;
    if (layoutSize.shortestSide > 0) {
      final extent = _barcodeExtent(barcode);
      score += (extent / layoutSize.shortestSide) * 500;
    }

    if (score > bestScore) {
      bestScore = score;
      best = barcode;
    }
  }

  if (best == null) return null;
  return normalizeStockBarcodeValue(best.rawValue!.trim());
}

/// Whether the barcode overlaps [scanWindow] in widget coordinates.
bool isBarcodeInsideScanWindow(
  Barcode barcode,
  Rect scanWindow, {
  required Size layoutSize,
  Size textureSize = Size.zero,
  bool allowWithoutPosition = false,
}) {
  final bounds = _barcodeBoundsInWidget(
    barcode,
    layoutSize: layoutSize,
    textureSize: textureSize,
  );
  if (bounds == null) return allowWithoutPosition;

  if (scanWindow.contains(bounds.center)) return true;

  final intersection = scanWindow.intersect(bounds);
  if (intersection.isEmpty) return false;

  final barcodeArea = bounds.width * bounds.height;
  if (barcodeArea <= 0) return true;

  final overlapArea = intersection.width * intersection.height;
  if (overlapArea / barcodeArea >= 0.08) return true;

  // Thin 1D strips (like EAN-8 on hang tags): enough width inside frame.
  if (bounds.width > 0 && intersection.width / bounds.width >= 0.45) {
    return true;
  }

  // Vertical 1D barcodes: enough height inside frame.
  if (bounds.height > 0 && intersection.height / bounds.height >= 0.45) {
    return true;
  }

  return false;
}

Rect? _barcodeBoundsInWidget(
  Barcode barcode, {
  required Size layoutSize,
  Size textureSize = Size.zero,
}) {
  final corners = barcode.corners;
  if (corners.isEmpty) return null;

  final mapped = _shouldMapBarcodeCornersToWidget(
    corners: corners,
    layoutSize: layoutSize,
    textureSize: textureSize,
  )
      ? corners
          .map(
            (corner) => mapTextureOffsetToWidget(
              corner,
              textureSize: textureSize,
              widgetSize: layoutSize,
            ),
          )
          .toList(growable: false)
      : corners;

  var minX = mapped.first.dx;
  var maxX = mapped.first.dx;
  var minY = mapped.first.dy;
  var maxY = mapped.first.dy;
  for (final corner in mapped) {
    if (corner.dx < minX) minX = corner.dx;
    if (corner.dx > maxX) maxX = corner.dx;
    if (corner.dy < minY) minY = corner.dy;
    if (corner.dy > maxY) maxY = corner.dy;
  }

  return Rect.fromLTRB(minX, minY, maxX, maxY);
}

bool _shouldMapBarcodeCornersToWidget({
  required List<Offset> corners,
  required Size layoutSize,
  required Size textureSize,
}) {
  if (textureSize.width <= 0 || textureSize.height <= 0) return false;
  if (layoutSize.width <= 0 || layoutSize.height <= 0) return false;
  if (kIsWeb) return true;

  for (final corner in corners) {
    if (corner.dx > layoutSize.width * 1.05 ||
        corner.dy > layoutSize.height * 1.05) {
      return true;
    }
  }

  return false;
}

/// Maps a point from camera texture space to on-screen widget space.
Offset mapTextureOffsetToWidget(
  Offset texturePoint, {
  required Size textureSize,
  required Size widgetSize,
  BoxFit fit = BoxFit.cover,
}) {
  final fittedTextureSize = applyBoxFit(fit, textureSize, widgetSize);

  var sx = fittedTextureSize.destination.width / textureSize.width;
  var sy = fittedTextureSize.destination.height / textureSize.height;

  switch (fit) {
    case BoxFit.fill:
      break;
    case BoxFit.contain:
      final s = min(sx, sy);
      sx = s;
      sy = s;
    case BoxFit.cover:
      final s = max(sx, sy);
      sx = s;
      sy = s;
    case BoxFit.fitWidth:
      sy = sx;
    case BoxFit.fitHeight:
      sx = sy;
    case BoxFit.none:
      sx = 1.0;
      sy = 1.0;
    case BoxFit.scaleDown:
      final s = min(sx, sy);
      sx = s;
      sy = s;
  }

  final textureWindow = Alignment.center.inscribe(
    Size(textureSize.width * sx, textureSize.height * sy),
    Rect.fromLTWH(0, 0, widgetSize.width, widgetSize.height),
  );

  return Offset(
    textureWindow.left + sx * texturePoint.dx,
    textureWindow.top + sy * texturePoint.dy,
  );
}

/// Light guard for unknown-format reads on web. Known 1D formats are trusted.
bool isPlausibleStockBarcodePayload(String value) {
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

  if (RegExp(r'^[A-Z]{2,5}-\d{3,8}$', caseSensitive: false).hasMatch(trimmed)) {
    return false;
  }

  final compact = trimmed.replaceAll(' ', '');
  if (RegExp(r'^\d+$').hasMatch(compact)) {
    if (RegExp(r'^[6-9]\d{9}$').hasMatch(compact)) return false;
    if (RegExp(r'^(\d)\1{5,}$').hasMatch(compact)) return false;
  }

  return true;
}

bool isBarcodeInScanWindow(
  Barcode barcode,
  Rect scanWindow, [
  BarcodeScanProfile profile = BarcodeScanProfile.billing,
]) {
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

/// Normalizes a scanned value for stock entry before saving.
String normalizeStockBarcodeValue(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return trimmed;

  final compact = trimmed.replaceAll(RegExp(r'\s+'), '');
  // Any numeric 1D barcode up to backend limit (100 chars).
  if (RegExp(r'^\d+$').hasMatch(compact) && compact.length <= 100) {
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
  final centerY = layoutSize.height * profile.scanWindowCenterYFactor;

  return Rect.fromCenter(
    center: Offset(layoutSize.width / 2, centerY),
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
