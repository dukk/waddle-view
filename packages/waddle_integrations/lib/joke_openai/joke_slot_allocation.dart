import 'dart:math' as math;

import 'package:waddle_shared/persistence/database.dart';

/// Builds the ordered list of category slots for one OpenAI request.
///
/// Respects per-category [InterestsJoke.minJokes] / [InterestsJoke.maxJokes]
/// (sanitized if min > max), existing [storedByCategoryId] counts, and
/// [budget] (caller caps by daily + rolling-window limits).
List<InterestsJoke> buildJokeRequestSlots({
  required List<InterestsJoke> eligibleSorted,
  required Map<String, int> storedByCategoryId,
  required int budget,
}) {
  if (budget <= 0 || eligibleSorted.isEmpty) {
    return [];
  }

  int stored(String id) => storedByCategoryId[id] ?? 0;

  final headroom = <String, int>{};
  for (final c in eligibleSorted) {
    final hi = math.max(c.minJokes, c.maxJokes);
    headroom[c.id] = math.max(0, hi - stored(c.id));
  }

  final slots = <InterestsJoke>[];

  bool addOne(InterestsJoke c) {
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

  // Phase 1: reduce deficit toward each category's minimum.
  while (slots.length < budget) {
    var progressed = false;
    for (final c in eligibleSorted) {
      final lo = math.min(c.minJokes, c.maxJokes);
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

  // Phase 2: distribute remaining budget across categories with headroom.
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
