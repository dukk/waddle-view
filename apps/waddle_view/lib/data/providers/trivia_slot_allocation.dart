import 'dart:math' as math;

import '../../persistence/database.dart';

/// Builds the ordered list of category slots for one OpenAI request.
List<TriviaCategory> buildTriviaRequestSlots({
  required List<TriviaCategory> eligibleSorted,
  required Map<String, int> storedByCategoryId,
  required int budget,
}) {
  if (budget <= 0 || eligibleSorted.isEmpty) {
    return [];
  }

  int stored(String id) => storedByCategoryId[id] ?? 0;

  final headroom = <String, int>{};
  for (final c in eligibleSorted) {
    final hi = math.max(c.minQuestions, c.maxQuestions);
    headroom[c.id] = math.max(0, hi - stored(c.id));
  }

  final slots = <TriviaCategory>[];

  bool addOne(TriviaCategory c) {
    if (slots.length >= budget) {
      return false;
    }
    final h = headroom[c.id] ?? 0;
    if (h <= 0) {
      return false;
    }
    headroom[c.id] = h - 1;
    slots.add(c);
    return true;
  }

  while (slots.length < budget) {
    var progressed = false;
    for (final c in eligibleSorted) {
      final lo = math.min(c.minQuestions, c.maxQuestions);
      final assigned = slots.where((s) => s.id == c.id).length;
      if (stored(c.id) + assigned >= lo) {
        continue;
      }
      if (addOne(c)) {
        progressed = true;
      }
      if (slots.length >= budget) {
        break;
      }
    }
    if (!progressed) {
      break;
    }
  }

  while (slots.length < budget) {
    var progressed = false;
    for (final c in eligibleSorted) {
      if (addOne(c)) {
        progressed = true;
      }
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
