import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/persistence/overlay_type_category.dart';
import 'package:waddle_shared/persistence/tables.dart';

void main() {
  const effectTypes = [
    kOverlayTypeShapeRain,
    kOverlayTypeBirthdayConfetti,
    kOverlayTypeBouncingMessage,
    kOverlayTypeFallingImages,
    kOverlayTypeMatrixRain,
    kOverlayTypeEdgeGlow,
    kOverlayTypeFloatingBalloons,
    kOverlayTypeCloudDrift,
  ];

  const widgetTypes = [
    kOverlayTypeStaticImage,
    kOverlayTypePhotoSlideshow,
    kOverlayTypeDigitalClock,
    kOverlayTypeAnalogClock,
    kOverlayTypeCalendarMonth,
    kOverlayTypeCalendarUpcoming,
    kOverlayTypeStockQuote,
    kOverlayTypeQrCode,
  ];

  test('every builtin overlay type has expected category', () {
    for (final t in effectTypes) {
      expect(overlayTypeCategory(t), kOverlayCategoryEffect);
      expect(overlayTypeRequiresPlacement(t), isFalse);
    }
    for (final t in widgetTypes) {
      expect(overlayTypeCategory(t), kOverlayCategoryWidget);
      expect(overlayTypeRequiresPlacement(t), isTrue);
    }
    expect(kBuiltinOverlayTypes.length, effectTypes.length + widgetTypes.length);
    for (final t in kBuiltinOverlayTypes) {
      expect(
        effectTypes.contains(t) || widgetTypes.contains(t),
        isTrue,
        reason: 'unexpected builtin $t',
      );
    }
  });

  test('hearts_rain is categorized as effect', () {
    expect(overlayTypeCategory(kOverlayTypeHeartsRain), kOverlayCategoryEffect);
    expect(overlayTypeRequiresPlacement(kOverlayTypeHeartsRain), isFalse);
  });

  test('unknown type without placement schema defaults to effect', () {
    expect(overlayTypeCategory('totally_unknown_overlay'), kOverlayCategoryEffect);
  });
}
