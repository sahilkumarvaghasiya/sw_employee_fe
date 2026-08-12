import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/web_camera_tuner.dart';

/// Zoom + torch controls for the web camera preview.
///
/// Zoom is the important one: it magnifies a small hang-tag barcode while the
/// phone stays at a comfortable ~20 cm, instead of the user moving closer until
/// they cross the lens's minimum focus distance and the image blurs.
///
/// Renders nothing when the browser exposes neither control, so native builds
/// and older browsers are unaffected.
class ScanCameraControls extends StatefulWidget {
  const ScanCameraControls({super.key, required this.tuning});

  final WebCameraTuning tuning;

  @override
  State<ScanCameraControls> createState() => _ScanCameraControlsState();
}

class _ScanCameraControlsState extends State<ScanCameraControls> {
  double? _zoom;
  bool _torchOn = false;

  @override
  void initState() {
    super.initState();
    _zoom = widget.tuning.zoomMin;
  }

  @override
  void didUpdateWidget(covariant ScanCameraControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tuning.zoomMin != oldWidget.tuning.zoomMin) {
      _zoom = widget.tuning.zoomMin;
    }
  }

  void _onZoomChanged(double value) {
    setState(() => _zoom = value);
    unawaited(setWebCameraZoom(value));
  }

  void _toggleTorch() {
    final next = !_torchOn;
    setState(() => _torchOn = next);
    unawaited(setWebCameraTorch(next));
  }

  @override
  Widget build(BuildContext context) {
    final tuning = widget.tuning;
    if (!tuning.hasControls) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (tuning.supportsZoom) ...[
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.zoom_in, size: 20),
              ),
              Expanded(
                child: Slider(
                  value: (_zoom ?? tuning.zoomMin!).clamp(
                    tuning.zoomMin!,
                    tuning.zoomMax!,
                  ),
                  min: tuning.zoomMin!,
                  max: tuning.zoomMax!,
                  activeColor: AppColors.emerald,
                  onChanged: _onZoomChanged,
                ),
              ),
            ] else
              const Spacer(),
            if (tuning.supportsTorch)
              IconButton(
                tooltip: _torchOn ? 'Turn off light' : 'Turn on light',
                onPressed: _toggleTorch,
                icon: Icon(
                  _torchOn ? Icons.flashlight_on : Icons.flashlight_off,
                  color: _torchOn ? AppColors.emerald : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
