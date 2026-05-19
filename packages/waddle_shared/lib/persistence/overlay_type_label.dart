import 'tables.dart';

/// Human-facing labels for overlay rows / [OverlayTypes] rows.
const Map<String, String> kOverlayTypeTitles = {
  kOverlayTypeShapeRain: 'Shape rain',
  kOverlayTypeBirthdayConfetti: 'Birthday confetti',
  kOverlayTypeBouncingMessage: 'Bouncing message',
  kOverlayTypeFallingImages: 'Falling images',
  kOverlayTypeMatrixRain: 'Matrix rain',
  kOverlayTypeEdgeGlow: 'Edge glow',
  kOverlayTypeFloatingBalloons: 'Floating balloons',
};

String _capitalizeToken(String word) {
  if (word.isEmpty) return word;
  return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
}

String _titleFromSegments(String overlayType) {
  final parts = overlayType.split('_').where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return overlayType;
  return parts.map(_capitalizeToken).join(' ');
}

/// Normalized label for cards, dialogs, and [OverlayTypes.label] seeding.
String overlayTypeLabel(String overlayType) {
  final key = overlayType.trim();
  if (key.isEmpty) return 'Overlay';
  return kOverlayTypeTitles[key] ?? _titleFromSegments(key);
}

/// All built-in overlay types for registry seeding.
Iterable<String> get kAllBuiltinOverlayTypes => kBuiltinOverlayTypes;
