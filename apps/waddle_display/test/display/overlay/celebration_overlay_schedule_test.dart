import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/display/overlay/celebration_overlay_schedule.dart';
import 'package:waddle_shared/persistence/display_overlay_row.dart';
import 'package:waddle_shared/persistence/tables.dart';

DisplayOverlayRow _row({String configJson = '{}'}) {
  return DisplayOverlayRow(
    id: 'test',
    overlayType: kOverlayTypeHeartsRain,
    name: 'Test',
    configJson: configJson,
    configJsonSchema: null,
    exampleConfigJson: null,
  );
}

void main() {
  test('matchesCelebrationOverlay without trigger is always true', () {
    final r = _row();
    expect(matchesCelebrationOverlay(r, DateTime(2026, 5, 10)), isTrue);
    expect(matchesCelebrationOverlay(r, DateTime(2026, 12, 25)), isTrue);
  });

  test('matchesCelebrationOverlay evaluates trigger signal', () {
    final r = _row(
      configJson: '{"trigger":{"signal":"party_mode","when":true}}',
    );
    expect(
      matchesCelebrationOverlay(
        r,
        DateTime(2026, 1, 1),
        runtimeSignals: {'party_mode': true},
      ),
      isTrue,
    );
    expect(
      matchesCelebrationOverlay(
        r,
        DateTime(2026, 1, 1),
        runtimeSignals: {'party_mode': false},
      ),
      isFalse,
    );
  });

  test('matchesCelebrationOverlay reads bool from signal map', () {
    final r = _row(
      configJson: '{"trigger":{"signal":"flag","when":false}}',
    );
    expect(
      matchesCelebrationOverlay(
        r,
        DateTime(2026, 1, 1),
        runtimeSignals: {'flag': {'bool': false}},
      ),
      isTrue,
    );
  });
}
