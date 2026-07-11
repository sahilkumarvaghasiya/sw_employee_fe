// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui';

Future<Uint8List?> captureCameraPreviewFrame({Rect? cropRect}) async {
  final videos = html.document.querySelectorAll('video');
  if (videos.isEmpty) return null;

  html.VideoElement? video;
  for (final element in videos) {
    final candidate = element as html.VideoElement;
    if (candidate.videoWidth > 0 && candidate.videoHeight > 0) {
      video = candidate;
      break;
    }
  }
  video ??= videos.first as html.VideoElement;

  final width = video.videoWidth;
  final height = video.videoHeight;
  if (width <= 0 || height <= 0) return null;

  final canvas = html.CanvasElement(width: width, height: height);
  final context = canvas.context2D;
  context.drawImage(video, 0, 0);

  html.CanvasElement output = canvas;
  if (cropRect != null) {
    final cropWidth = (cropRect.width * width).round().clamp(1, width);
    final cropHeight = (cropRect.height * height).round().clamp(1, height);
    final cropX = (cropRect.left * width).round().clamp(0, width - cropWidth);
    final cropY =
        (cropRect.top * height).round().clamp(0, height - cropHeight);

    final cropped = html.CanvasElement(width: cropWidth, height: cropHeight);
    final croppedContext = cropped.context2D;
    croppedContext.drawImageScaledFromSource(
      canvas,
      cropX,
      cropY,
      cropWidth,
      cropHeight,
      0,
      0,
      cropWidth,
      cropHeight,
    );
    output = cropped;
  }

  return _canvasToPng(output);
}

Uint8List? _canvasToPng(html.CanvasElement canvas) {
  try {
    final dataUrl = canvas.toDataUrl('image/png');
    final commaIndex = dataUrl.indexOf(',');
    if (commaIndex == -1) return null;
    return base64Decode(dataUrl.substring(commaIndex + 1));
  } catch (_) {
    return null;
  }
}
