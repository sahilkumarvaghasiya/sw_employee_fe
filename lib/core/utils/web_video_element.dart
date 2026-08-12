import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Locates the camera preview `<video>` that `mobile_scanner` created.
///
/// Both the camera tuner and the decode pump attach to this same element, so
/// they always operate on the stream the user is actually looking at.
web.HTMLVideoElement? findLiveScannerVideo() {
  for (final video in _findVideoElements()) {
    if (video.videoWidth <= 0 || video.videoHeight <= 0) continue;
    if (video.srcObject == null) continue;
    return video;
  }
  return null;
}

/// The live video track behind the preview, used to read and apply camera
/// constraints (resolution, focus, zoom, torch).
web.MediaStreamTrack? findLiveScannerTrack() {
  for (final video in _findVideoElements()) {
    if (video.videoWidth <= 0 || video.videoHeight <= 0) continue;

    final source = video.srcObject;
    if (source == null) continue;

    for (final track in (source as web.MediaStream).getVideoTracks().toDart) {
      if (track.readyState == 'live') return track;
    }
  }
  return null;
}

/// Flutter hosts platform views in the light DOM, so a plain document query
/// normally finds the preview. Some engine versions place them behind a shadow
/// root instead, so fall back to a one-level shadow sweep before giving up.
List<web.HTMLVideoElement> _findVideoElements() {
  final direct = _collectVideos(web.document.querySelectorAll('video'));
  if (direct.isNotEmpty) return direct;

  final hosts = web.document.querySelectorAll('*');
  final nested = <web.HTMLVideoElement>[];
  for (var i = 0; i < hosts.length; i++) {
    final shadowRoot = (hosts.item(i) as web.Element?)?.shadowRoot;
    if (shadowRoot == null) continue;
    nested.addAll(_collectVideos(shadowRoot.querySelectorAll('video')));
  }
  return nested;
}

List<web.HTMLVideoElement> _collectVideos(web.NodeList nodes) {
  return [
    for (var i = 0; i < nodes.length; i++)
      if (nodes.item(i) case final node?) node as web.HTMLVideoElement,
  ];
}
