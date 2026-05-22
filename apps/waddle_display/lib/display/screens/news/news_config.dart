import 'package:flutter/material.dart';

String readNewsQrMode(Map<String, dynamic> config, {bool legacyImageOnRight = false}) {
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

bool newsQrImageOverlayBottom(String mode) => mode == 'image_overlay_bottom';
