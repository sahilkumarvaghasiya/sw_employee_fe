import 'dart:ui';

/// What the live web camera track can do after barcode tuning was applied.
///
/// Every field is feature-detected: a browser that exposes nothing still
/// returns a valid instance with the capabilities switched off.
class WebCameraTuning {
  const WebCameraTuning({
    required this.applied,
    this.resolution = Size.zero,
    this.zoomMin,
    this.zoomMax,
    this.zoomStep,
    this.supportsTorch = false,
    this.supportsContinuousFocus = false,
  });

  /// No live camera track was found, or the platform is not web.
  const WebCameraTuning.unavailable() : this(applied: false);

  /// Whether a live video track was found and constraints were applied to it.
  final bool applied;

  /// Resolution the track actually settled on, per `getSettings()`.
  ///
  /// This is the number that proves the fix landed: the untuned
  /// `mobile_scanner` web path reports 640x480 here.
  final Size resolution;

  final double? zoomMin;
  final double? zoomMax;
  final double? zoomStep;
  final bool supportsTorch;
  final bool supportsContinuousFocus;

  bool get supportsZoom =>
      zoomMin != null && zoomMax != null && zoomMax! > zoomMin!;

  bool get hasControls => supportsZoom || supportsTorch;

  /// True once the frame carries enough pixels for a small hang-tag barcode.
  bool get isHighResolution => resolution.width >= 1280;
}
