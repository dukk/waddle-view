import 'dart:math' as math;

import 'package:waddle_shared/layout/collage_template_ids.dart';

import 'curator_content_pools.dart';

export 'package:waddle_shared/layout/collage_template_ids.dart';

/// One collage cell: target **width ÷ height** when the photo is shown with [BoxFit.cover].
class CollageSlotSpec {
  const CollageSlotSpec({
    required this.idealAspect,
    this.heroWeight = 0,
  });

  /// Desired width/height ratio for the frame (landscape > 1, portrait < 1).
  final double idealAspect;

  /// When &gt; 0, prefer higher-resolution images in this slot (featured / hero tiles).
  final double heroWeight;
}

List<CollageSlotSpec>? collageSlotSpecsForTemplate(String templateId) {
  switch (templateId) {
    case kCollageTemplateNineSquareAsymmetric:
      return List<CollageSlotSpec>.generate(
        9,
        (i) => CollageSlotSpec(
          idealAspect: 1,
          heroWeight: (i == 5 || i == 6) ? 1 : 0,
        ),
      );
    case kCollageTemplateElevenSymmetricHub:
      const p = 9 / 16;
      const landSmall = 4 / 3;
      const hub = 16 / 9;
      return [
        const CollageSlotSpec(idealAspect: p),
        const CollageSlotSpec(idealAspect: p),
        const CollageSlotSpec(idealAspect: landSmall),
        const CollageSlotSpec(idealAspect: landSmall),
        const CollageSlotSpec(idealAspect: landSmall),
        const CollageSlotSpec(idealAspect: hub, heroWeight: 2),
        const CollageSlotSpec(idealAspect: landSmall),
        const CollageSlotSpec(idealAspect: landSmall),
        const CollageSlotSpec(idealAspect: landSmall),
        const CollageSlotSpec(idealAspect: p),
        const CollageSlotSpec(idealAspect: p),
      ];
    case kCollageTemplateNineMixedGrid:
      const narrow = 1 / 2;
      const land = 3 / 2;
      const heroP = 3 / 4;
      return [
        const CollageSlotSpec(idealAspect: narrow),
        const CollageSlotSpec(idealAspect: narrow),
        const CollageSlotSpec(idealAspect: land),
        const CollageSlotSpec(idealAspect: heroP, heroWeight: 1),
        const CollageSlotSpec(idealAspect: heroP, heroWeight: 1),
        const CollageSlotSpec(idealAspect: land),
        const CollageSlotSpec(idealAspect: land),
        const CollageSlotSpec(idealAspect: narrow),
        const CollageSlotSpec(idealAspect: narrow),
      ];
    case kCollageTemplateNineDynamicHub:
      const side = 2 / 3;
      const corner = 1.0;
      return [
        const CollageSlotSpec(idealAspect: side),
        const CollageSlotSpec(idealAspect: side),
        const CollageSlotSpec(idealAspect: side),
        const CollageSlotSpec(idealAspect: side),
        const CollageSlotSpec(idealAspect: 2, heroWeight: 3),
        const CollageSlotSpec(idealAspect: corner),
        const CollageSlotSpec(idealAspect: corner),
        const CollageSlotSpec(idealAspect: corner),
        const CollageSlotSpec(idealAspect: corner),
      ];
    case kCollageTemplateTwelveCircleBand:
      const stripP = 3 / 4;
      const land = 16 / 9;
      return [
        const CollageSlotSpec(idealAspect: stripP),
        const CollageSlotSpec(idealAspect: stripP),
        const CollageSlotSpec(idealAspect: stripP),
        const CollageSlotSpec(idealAspect: stripP),
        const CollageSlotSpec(idealAspect: stripP),
        const CollageSlotSpec(idealAspect: land, heroWeight: 1),
        const CollageSlotSpec(idealAspect: 1, heroWeight: 3),
        const CollageSlotSpec(idealAspect: land, heroWeight: 1),
        const CollageSlotSpec(idealAspect: 0.78),
        const CollageSlotSpec(idealAspect: 0.78),
        const CollageSlotSpec(idealAspect: 0.78),
        const CollageSlotSpec(idealAspect: 0.78),
      ];
    default:
      return null;
  }
}

int collageSlotCount(String templateId) =>
    collageSlotSpecsForTemplate(templateId)?.length ?? 0;

double _slotPhotoScore(CollageSlotSpec spec, PhotoCuratorMetric? m) {
  final ideal = spec.idealAspect;
  var aspectPart = 0.0;
  final r = m?.aspectRatio;
  if (r != null && r > 0 && ideal > 0) {
    aspectPart = -((math.log(r) - math.log(ideal)).abs());
  }
  final area = m?.pixelArea ?? 0;
  final hero = spec.heroWeight * math.log(1 + area) * 0.02;
  return aspectPart * 12 + hero;
}

/// Picks one photo per slot; keys are `'${choiceKey}_$index'`.
///
/// Returns `null` when [templateId] is unknown (caller should fall back to naive pool picks).
Map<String, String>? assignPhotosToCollageSlots({
  required String templateId,
  required String choiceKey,
  required List<String> pool,
  required Set<String> reserved,
  required Map<String, PhotoCuratorMetric> photoMetrics,
  required math.Random random,
}) {
  final slots = collageSlotSpecsForTemplate(templateId);
  if (slots == null) {
    return null;
  }
  final available = pool.where((id) => !reserved.contains(id)).toList()
    ..shuffle(random);
  if (available.isEmpty) {
    return {};
  }
  final order = List<int>.generate(slots.length, (i) => i);
  order.sort((a, b) {
    final ha = slots[a].heroWeight;
    final hb = slots[b].heroWeight;
    if (ha != hb) {
      return hb.compareTo(ha);
    }
    final da = (slots[a].idealAspect - 1).abs();
    final db = (slots[b].idealAspect - 1).abs();
    return db.compareTo(da);
  });

  final out = <String, String>{};
  final remaining = List<String>.from(available);
  for (final si in order) {
    if (remaining.isEmpty) {
      break;
    }
    final spec = slots[si];
    String? bestId;
    var best = double.negativeInfinity;
    for (final id in remaining) {
      final s = _slotPhotoScore(spec, photoMetrics[id]);
      if (s > best) {
        best = s;
        bestId = id;
      }
    }
    final pick = bestId ?? remaining.first;
    out['${choiceKey}_$si'] = pick;
    remaining.remove(pick);
  }
  return out;
}
