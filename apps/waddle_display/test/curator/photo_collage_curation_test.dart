import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/curator/curator_content_pools.dart';
import 'package:waddle_display/curator/photo_collage_curation.dart';

void main() {
  test('assignPhotosToCollageSlots maps wide photo to center hub', () {
    final metrics = <String, PhotoCuratorMetric>{
      'wide': const PhotoCuratorMetric(pixelWidth: 1920, pixelHeight: 1080),
      'tall': const PhotoCuratorMetric(pixelWidth: 900, pixelHeight: 1600),
    };
    final pool = ['wide', 'tall'];
    final out = assignPhotosToCollageSlots(
      templateId: kCollageTemplateElevenSymmetricHub,
      choiceKey: 'main_pexels_photo_collage',
      pool: pool,
      reserved: {},
      photoMetrics: metrics,
      random: Random(0),
    );
    expect(out, isNotNull);
    expect(out!['main_pexels_photo_collage_5'], 'wide');
  });

  test('assignPhotosToCollageSlots prefers large square heroes on nine-square grid', () {
    final metrics = <String, PhotoCuratorMetric>{
      for (var i = 0; i < 9; i++)
        'p$i': PhotoCuratorMetric(
          pixelWidth: 100 + i,
          pixelHeight: 100 + i,
        ),
    };
    final pool = List<String>.generate(9, (i) => 'p$i');
    final out = assignPhotosToCollageSlots(
      templateId: kCollageTemplateNineSquareAsymmetric,
      choiceKey: 'k',
      pool: pool,
      reserved: {},
      photoMetrics: metrics,
      random: Random(1),
    );
    expect(out, isNotNull);
    expect(out!.length, 9);
    final heroA = out['k_5'];
    final heroB = out['k_6'];
    expect(heroA, isNot(equals(heroB)));
    expect({heroA, heroB}, contains('p8'));
    expect({heroA, heroB}, contains('p7'));
  });

  test('collageSlotCount matches template sizes', () {
    expect(collageSlotCount(kCollageTemplateNineSquareAsymmetric), 9);
    expect(collageSlotCount(kCollageTemplateElevenSymmetricHub), 11);
    expect(collageSlotCount(kCollageTemplateNineMixedGrid), 9);
    expect(collageSlotCount(kCollageTemplateNineDynamicHub), 9);
    expect(collageSlotCount(kCollageTemplateTwelveCircleBand), 12);
  });
}
