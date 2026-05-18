import 'package:test/test.dart';
import 'package:waddle_data_providers/home_assistant/home_assistant_state_parser.dart';

void main() {
  test('parseHomeAssistantStatePayload extracts state and attributes', () {
    const body = '''
{
  "entity_id": "sensor.kitchen_temperature",
  "state": "21.5",
  "attributes": {
    "friendly_name": "Kitchen temperature",
    "unit_of_measurement": "°C"
  },
  "last_updated": "2016-05-30T21:50:30.529465+00:00"
}
''';
    final parsed = parseHomeAssistantStatePayload(body);
    expect(parsed, isNotNull);
    expect(parsed!.state, '21.5');
    expect(parsed.friendlyName, 'Kitchen temperature');
    expect(parsed.lastUpdatedMs, isNotNull);
    expect(parsed.attributesJson, contains('unit_of_measurement'));
  });

  test('homeAssistantBinarySensorOn recognizes on state', () {
    expect(homeAssistantBinarySensorOn('on'), isTrue);
    expect(homeAssistantBinarySensorOn('OFF'), isFalse);
    expect(homeAssistantBinarySensorOn('unavailable'), isFalse);
  });
}
