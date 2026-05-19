import 'dart:convert';
import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:waddle_shared/persistence/display_overlay_floating_balloons_settings.dart';

void main() {
  group('FloatingBalloonsScheduleSettings.parse', () {
    test('uses defaults for empty config', () {
      final s = FloatingBalloonsScheduleSettings.parse('{}');
      expect(s.colorHexes, isEmpty);
      expect(
        s.effectiveColorHexes,
        kFloatingBalloonsDefaultColorHexes,
      );
      expect(
        s.spawnIntervalSec,
        FloatingBalloonsScheduleSettings.defaults.spawnIntervalSec,
      );
      expect(s.riseSpeed, 85);
      expect(s.maxActive, 6);
      expect(s.clusterChance, 0.4);
    });

    test('parses spawn_interval_sec down to minimum of 1', () {
      final s = FloatingBalloonsScheduleSettings.parse(
        '{"spawn_interval_sec":1}',
      );
      expect(s.spawnIntervalSec, 1);
    });

    test('parses colors and clamps motion', () {
      final s = FloatingBalloonsScheduleSettings.parse(
        '{"colors":["#AABBCC","#11223344"],'
        '"spawn_interval_sec":0,"rise_speed":900,'
        '"max_active":20,"cluster_chance":2,'
        '"balloon_scale":0.5,"scale_jitter":3,"opacity":0.05}',
      );
      expect(s.colorHexes, ['#AABBCC', '#11223344']);
      expect(s.spawnIntervalSec, kFloatingBalloonsSpawnIntervalSecMin);
      expect(s.riseSpeed, kFloatingBalloonsRiseSpeedPxPerSecMax);
      expect(s.maxActive, kFloatingBalloonsMaxActiveMax);
      expect(s.clusterChance, 1.0);
      expect(s.balloonScale, kFloatingBalloonsBalloonScaleMax);
      expect(s.scaleJitter, kFloatingBalloonsScaleJitterMax);
      expect(s.opacity, 0.2);
    });
  });

  group('pickFloatingBalloonClusterColors', () {
    test('assigns distinct colors when palette is large enough', () {
      final rng = math.Random(1);
      final colors = pickFloatingBalloonClusterColors(
        const ['#111111', '#222222', '#333333', '#444444'],
        3,
        rng,
      );
      expect(colors.toSet().length, 3);
    });
  });

  group('pickFloatingBalloonClusterSize', () {
    test('returns 1 when cluster chance is zero', () {
      final rng = math.Random(99);
      expect(
        pickFloatingBalloonClusterSize(rng, clusterChance: 0),
        1,
      );
    });

    test('returns only 3, 5, or 8 when clustering', () {
      final rng = math.Random(42);
      for (var i = 0; i < 50; i++) {
        final size = pickFloatingBalloonClusterSize(rng, clusterChance: 1);
        expect(kFloatingBalloonsClusterSizes, contains(size));
      }
    });
  });

  group('floatingBalloonClusterLayoutOffsets', () {
    test('defines layouts for cluster sizes 3, 5, and 8', () {
      expect(floatingBalloonClusterLayoutOffsets(3), hasLength(3));
      expect(floatingBalloonClusterLayoutOffsets(5), hasLength(5));
      expect(floatingBalloonClusterLayoutOffsets(8), hasLength(8));
    });
  });

  group('randomFloatingBalloonClusterLayoutOffsets', () {
    test('produces different layouts across spawns', () {
      final a = randomFloatingBalloonClusterLayoutOffsets(5, math.Random(1));
      final b = randomFloatingBalloonClusterLayoutOffsets(5, math.Random(2));
      expect(a, isNot(equals(b)));
    });

    test('differs from fixed base layout', () {
      final base = floatingBalloonClusterLayoutOffsets(3);
      final random = randomFloatingBalloonClusterLayoutOffsets(3, math.Random(7));
      expect(random, isNot(equals(base)));
    });
  });

  group('normalizeFloatingBalloonsConfigJsonString', () {
    test('accepts valid config', () {
      final out = normalizeFloatingBalloonsConfigJsonString(
        '{"colors":["#AABBCC"],"spawn_interval_sec":30,'
        '"rise_speed":120,"max_active":4,"cluster_chance":0.5,'
        '"balloon_scale":0.1,"scale_jitter":0.2,"opacity":0.8}',
      );
      expect(out, isNotNull);
      final map = jsonDecode(out!) as Map<String, dynamic>;
      expect(map['colors'], ['#AABBCC']);
      expect(map['spawn_interval_sec'], 30);
      expect(map['rise_speed'], 120);
    });

    test('rejects unknown keys', () {
      expect(
        normalizeFloatingBalloonsConfigJsonString('{"extra":1}'),
        isNull,
      );
    });

    test('rejects invalid color hex', () {
      expect(
        normalizeFloatingBalloonsConfigJsonString('{"colors":["not-a-color"]}'),
        isNull,
      );
    });
  });
}
