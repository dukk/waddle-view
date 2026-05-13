import 'dart:math' as math;

import 'package:waddle_shared/persistence/database.dart';

/// Builds the ordered list of category slots for one OpenAI request using
/// round-robin over [eligibleSorted], starting at [roundRobinStartIndex].
List<TriviaCategory> buildTriviaRequestSlots({
  required List<TriviaCategory> eligibleSorted,
  required Map<String, int> storedByCategoryId,
  required int budget,
  required int roundRobinStartIndex,
}) {
  if (budget <= 0 || eligibleSorted.isEmpty) {
    return [];
  }

  final n = eligibleSorted.length;
  final start = roundRobinStartIndex % n;

  int stored(String id) => storedByCategoryId[id] ?? 0;

  final headroom = <String, int>{};
  for (final c in eligibleSorted) {
    final hi = math.max(c.minQuestions, c.maxQuestions);
    headroom[c.id] = math.max(0, hi - stored(c.id));
  }

  final slots = <TriviaCategory>[];

  while (slots.length < budget) {
    var progressed = false;
    for (var j = 0; j < n; j++) {
      final c = eligibleSorted[(start + j) % n];
      final h = headroom[c.id] ?? 0;
      if (h <= 0) {
        continue;
      }
      headroom[c.id] = h - 1;
      slots.add(c);
      progressed = true;
      if (slots.length >= budget) {
        break;
      }
    }
    if (!progressed) {
      break;
    }
  }

  return slots;
}
