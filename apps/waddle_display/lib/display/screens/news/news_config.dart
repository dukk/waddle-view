import 'package:flutter/material.dart';

String readNewsQrMode(
  Map<String, dynamic> config, {
  bool legacyImageOnRight = false,
}) {
  final raw = config['qrMode'];
  if (raw is String && raw.trim().isNotEmpty) {
    return raw.trim();
  }
  if (legacyImageOnRight) {
    return 'right';
  }
  return 'left';
}

BoxFit readNewsImageFit(Map<String, dynamic> config) {
  final raw = config['imageFit'];
  if (raw is! String) {
    return BoxFit.cover;
  }
  switch (raw.trim()) {
    case 'contain':
      return BoxFit.contain;
    case 'fill':
      return BoxFit.fill;
    case 'fitWidth':
      return BoxFit.fitWidth;
    case 'fitHeight':
      return BoxFit.fitHeight;
    case 'scaleDown':
      return BoxFit.scaleDown;
    case 'cover':
    default:
      return BoxFit.cover;
  }
}

bool newsQrVisible(String mode) => mode != 'hidden';

bool newsQrOnRight(String mode) => mode == 'right';

/// Image-overlay QR placement, or null when QR is hidden / beside text.
Alignment? newsQrImageOverlayAlignment(String mode) {
  switch (mode) {
    case 'image_overlay_top_left':
      return Alignment.topLeft;
    case 'image_overlay_top':
      return Alignment.topCenter;
    case 'image_overlay_top_right':
      return Alignment.topRight;
    case 'image_overlay_bottom_left':
      return Alignment.bottomLeft;
    case 'image_overlay_bottom':
      return Alignment.bottomCenter;
    case 'image_overlay_bottom_right':
      return Alignment.bottomRight;
    case 'image_overlay_left':
      return Alignment.centerLeft;
    case 'image_overlay_right':
      return Alignment.centerRight;
    default:
      return null;
  }
}

bool newsQrImageOverlay(String mode) =>
    newsQrImageOverlayAlignment(mode) != null;

/// [news_grid] QR mode; defaults to [hidden].
String readNewsGridQrMode(Map<String, dynamic> config) {
  final raw = config['qrMode'];
  if (raw is String && raw.trim().isNotEmpty) {
    return raw.trim();
  }
  return 'hidden';
}

bool readNewsGridShowSummary(Map<String, dynamic> config) {
  final v = config['showSummary'];
  if (v is bool) {
    return v;
  }
  return false;
}

/// Flutter [Alignment] for [BoxFit.cover] from normalized focal (0..1), or a
/// slight top bias when focal is unknown.
Alignment newsImageAlignment({double? focalX, double? focalY}) {
  if (focalX != null && focalY != null) {
    return Alignment(
      (focalX.clamp(0.0, 1.0) * 2) - 1,
      (focalY.clamp(0.0, 1.0) * 2) - 1,
    );
  }
  return const Alignment(0, -0.3);
}
