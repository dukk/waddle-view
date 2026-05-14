import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../curation/reject_filter_context.dart';
import '../data_model/joke_candidate.dart';
import '../persistence/database.dart';

String jokeStableId(String categoryId, String setup, String punchline) {
  final h = sha256.convert(utf8.encode('$categoryId\x00$setup\x00$punchline'));
  return h.toString();
}

/// Persists [candidates] into [db.jokes] with stable ids and reject-term
/// suppression. Skips rows with unknown category ids.
Future<int> ingestJokeCandidates({
  required AppDatabase db,
  required RejectFilterContext rejectCtx,
  required Set<String> allowedCategoryIds,
  required DateTime createdAt,
  required Iterable<JokeCandidate> candidates,
}) async {
  var inserted = 0;
  for (final c in candidates) {
    if (!allowedCategoryIds.contains(c.categoryId)) {
      continue;
    }
    if (c.setup.isEmpty || c.punchline.isEmpty) {
      continue;
    }
    final jokeId = jokeStableId(c.categoryId, c.setup, c.punchline);
    final isBlocked = rejectCtx.isBlockedAny([c.setup, c.punchline]);
    await db.into(db.jokes).insert(
          JokesCompanion.insert(
            id: jokeId,
            categoryId: c.categoryId,
            setup: c.setup,
            punchline: c.punchline,
            createdAtMs: createdAt,
            suppressed: Value(isBlocked),
          ),
          onConflict: DoUpdate(
            (old) => JokesCompanion(
              categoryId: Value(c.categoryId),
              setup: Value(c.setup),
              punchline: Value(c.punchline),
              createdAtMs: Value(createdAt),
              suppressed: isBlocked
                  ? const Value(true)
                  : const Value.absent(),
            ),
          ),
        );
    inserted++;
  }
  return inserted;
}
