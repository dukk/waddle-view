import 'dart:convert';

import 'package:test/test.dart';
import 'package:waddle_shared/persistence/display_overlay_cloud_drift_settings.dart';

void main() {
  test('normalizeCloudDriftSettingsJsonString empty object', () {
    expect(normalizeCloudDriftSettingsJsonString(''), '{}');
    expect(normalizeCloudDriftSettingsJsonString('  {}  '), '{}');
  });

  test('normalizeCloudDriftSettingsJsonString preserves valid keys', () {
    final raw =
        '{"cloud_type":"cirrus","scatter":0.5,"density":0.4,"opacity":0.5,'
        '"color":"#AABBCC"}';
    final out = normalizeCloudDriftSettingsJsonString(raw);
    expect(out, isNotNull);
    expect(jsonDecode(out!), {
      'cloud_type': 'cirrus',
      'scatter': 0.5,
      'density': 0.4,
      'opacity': 0.5,
      'color': '#AABBCC',
    });
  });

  test('normalizeCloudDriftSettingsJsonString strips legacy message keys', () {
    final out = normalizeCloudDriftSettingsJsonString(
      '{"messages":["Hi"],"message_interval_sec":40,"opacity":0.4}',
    );
    expect(out, isNotNull);
    expect(jsonDecode(out!), {'opacity': 0.4});
  });

  test('normalize clamps scatter density and opacity', () {
    final out = normalizeCloudDriftSettingsJsonString(
      '{"scatter":-1,"density":2,"opacity":0.99}',
    );
    expect(jsonDecode(out!), {
      'scatter': 0.0,
      'density': 0.9,
      'opacity': 0.85,
    });
  });

  test('normalize rejects invalid cloud_type or color', () {
    expect(
      normalizeCloudDriftSettingsJsonString('{"cloud_type":"nimbus"}'),
      isNull,
    );
    expect(
      normalizeCloudDriftSettingsJsonString('{"color":"not-a-color"}'),
      isNull,
    );
    expect(normalizeCloudDriftSettingsJsonString('{"scatter":"wide"}'), isNull);
  });

  test('CloudDriftScheduleSettings.parse defaults', () {
    final s = CloudDriftScheduleSettings.parse('{}');
    expect(s.cloudType, kCloudDriftDefaultCloudType);
    expect(s.colorHex, kCloudDriftDefaultColorHex);
    expect(s.scatter, CloudDriftScheduleSettings.defaults.scatter);
    expect(s.density, CloudDriftScheduleSettings.defaults.density);
    expect(s.opacity, CloudDriftScheduleSettings.defaults.opacity);
  });

  test('CloudDriftScheduleSettings.parse reads values', () {
    final s = CloudDriftScheduleSettings.parse(
      '{"cloud_type":"cumulus","scatter":0.8,"density":0.6,"opacity":0.7,'
      '"color":"#112233"}',
    );
    expect(s.cloudType, 'cumulus');
    expect(s.scatter, 0.8);
    expect(s.density, 0.6);
    expect(s.opacity, 0.7);
    expect(s.colorHex, '#112233');
  });
}
