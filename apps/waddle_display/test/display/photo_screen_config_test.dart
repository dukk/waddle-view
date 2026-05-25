import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/display/screens/photo/photo_screen_config.dart';

void main() {
  test('showPhotographerOverlayFromConfig defaults off and respects true', () {
    expect(showPhotographerOverlayFromConfig({}), isFalse);
    expect(
      showPhotographerOverlayFromConfig({'showPhotographerOverlay': true}),
      isTrue,
    );
    expect(
      showPhotographerOverlayFromConfig({'showPhotographerOverlay': 'on'}),
      isTrue,
    );
    expect(
      showPhotographerOverlayFromConfig({'showPhotographerOverlay': false}),
      isFalse,
    );
  });

  test('photoScreenConfigBool parses bool int and string', () {
    expect(
      photoScreenConfigBool({'k': true}, 'k', defaultValue: false),
      isTrue,
    );
    expect(
      photoScreenConfigBool({'k': false}, 'k', defaultValue: true),
      isFalse,
    );
    expect(photoScreenConfigBool({'k': 1}, 'k', defaultValue: false), isTrue);
    expect(photoScreenConfigBool({'k': 0}, 'k', defaultValue: true), isFalse);
    expect(
      photoScreenConfigBool({'k': 'on'}, 'k', defaultValue: false),
      isTrue,
    );
    expect(
      photoScreenConfigBool({'k': 'OFF'}, 'k', defaultValue: true),
      isFalse,
    );
    expect(
      photoScreenConfigBool({'k': 'maybe'}, 'k', defaultValue: true),
      isTrue,
    );
    expect(photoScreenConfigBool({}, 'missing', defaultValue: true), isTrue);
  });
}
