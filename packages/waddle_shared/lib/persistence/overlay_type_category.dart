import 'dart:convert';

import 'config_json_documentation.dart';
import 'tables.dart';

/// Overlay catalog category: full-screen / motion effects (no viewport placement).
const String kOverlayCategoryEffect = 'effect';

/// Overlay catalog category: positioned viewport widgets (clocks, images, etc.).
const String kOverlayCategoryWidget = 'widget';

/// Built-in overlay types that render without viewport placement anchors.
const Set<String> kOverlayTypeEffectTypes = {
  kOverlayTypeShapeRain,
  kOverlayTypeHeartsRain,
  kOverlayTypeBirthdayConfetti,
  kOverlayTypeBouncingMessage,
  kOverlayTypeFallingImages,
  kOverlayTypeMatrixRain,
  kOverlayTypeEdgeGlow,
  kOverlayTypeFloatingBalloons,
  kOverlayTypeCloudDrift,
};

/// Built-in overlay types that require viewport placement (`x`, `y`, `scale`, …).
const Set<String> kOverlayTypeWidgetTypes = {
  kOverlayTypeStaticImage,
  kOverlayTypePhotoSlideshow,
  kOverlayTypeDigitalClock,
  kOverlayTypeAnalogClock,
  kOverlayTypeCalendarMonth,
  kOverlayTypeCalendarUpcoming,
  kOverlayTypeStockQuote,
  kOverlayTypeQrCode,
};

/// Returns [kOverlayCategoryEffect] or [kOverlayCategoryWidget] for [overlayType].
String overlayTypeCategory(String overlayType) {
  final key = overlayType.trim();
  if (kOverlayTypeEffectTypes.contains(key)) {
    return kOverlayCategoryEffect;
  }
  if (kOverlayTypeWidgetTypes.contains(key)) {
    return kOverlayCategoryWidget;
  }
  if (_schemaImpliesPlacement(key)) {
    return kOverlayCategoryWidget;
  }
  return kOverlayCategoryEffect;
}

/// True when [overlayType] is a positioned viewport widget.
bool overlayTypeRequiresPlacement(String overlayType) =>
    overlayTypeCategory(overlayType) == kOverlayCategoryWidget;

int overlayTypeCategorySortOrder(String category) {
  switch (category) {
    case kOverlayCategoryEffect:
      return 0;
    case kOverlayCategoryWidget:
      return 1;
    default:
      return 2;
  }
}

bool _schemaImpliesPlacement(String overlayType) {
  final doc = displayOverlayConfigJsonDocForType(overlayType);
  final schemaRaw = doc.schema;
  if (schemaRaw == null || schemaRaw.trim().isEmpty) {
    return false;
  }
  try {
    final decoded = jsonDecode(schemaRaw);
    if (decoded is! Map) {
      return false;
    }
    final properties = decoded['properties'];
    if (properties is! Map) {
      return false;
    }
    final x = properties['x'];
    final y = properties['y'];
    if (x is! Map || y is! Map) {
      return false;
    }
    if (x['type'] != 'number' || y['type'] != 'number') {
      return false;
    }
    return true;
  } catch (_) {
    return false;
  }
}
