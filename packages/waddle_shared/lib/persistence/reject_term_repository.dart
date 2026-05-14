import 'package:drift/drift.dart';

import '../curation/reject_filter.dart';
import 'database.dart';
import 'tables.dart';

/// Validation/normalization wrapper for a reject-term mutation.
class RejectTermInput {
  RejectTermInput._({
    required this.term,
    required this.action,
  });

  /// Normalized term (lowercased, trimmed). Single word; whitespace collapses
  /// to single spaces but operators are expected to seed single tokens.
  final String term;

  /// One of [kRejectTermActionCensor] or [kRejectTermActionBlock].
  final String action;

  /// Default id derived from [term] for new rows.
  String get defaultId => 'op_${term.replaceAll(RegExp(r'\s+'), '_')}';

  /// Parses [rawTerm] and [rawAction] returning a [RejectTermInput] or null if
  /// either is invalid. Trims and lowercases [rawTerm]; requires [rawAction]
  /// to be `censor` or `block` (case-insensitive).
  static RejectTermInput? parse({
    required String? rawTerm,
    required String? rawAction,
  }) {
    final t = rawTerm?.trim().toLowerCase() ?? '';
    if (t.isEmpty) {
      return null;
    }
    final a = rawAction?.trim().toLowerCase() ?? '';
    if (a != kRejectTermActionCensor && a != kRejectTermActionBlock) {
      return null;
    }
    return RejectTermInput._(term: t, action: a);
  }
}

/// CRUD repository for [RejectTerms]. Mirrors the [ContentSuppressionRepository]
/// style used elsewhere in `waddle_shared`.
class RejectTermRepository {
  RejectTermRepository(this._db, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  /// Returns every reject term, ordered by [RejectTerms.term].
  Future<List<RejectTerm>> listAll() {
    return (_db.select(_db.rejectTerms)
          ..orderBy([(t) => OrderingTerm.asc(t.term)]))
        .get();
  }

  /// Stream of all reject terms for repositories that cache the list.
  Stream<List<RejectTerm>> watchAll() {
    return (_db.select(_db.rejectTerms)
          ..orderBy([(t) => OrderingTerm.asc(t.term)]))
        .watch();
  }

  /// In-memory snapshot suitable for [RejectFilterTerm]-based pure helpers.
  Future<List<RejectFilterTerm>> snapshotForFilter() async {
    final rows = await listAll();
    return [
      for (final r in rows) RejectFilterTerm(term: r.term, action: r.action),
    ];
  }

  /// Inserts or updates the row identified by [input]. When [id] is null, the
  /// repository looks up an existing row by [RejectTermInput.term]; if missing,
  /// it generates [RejectTermInput.defaultId]. Returns the upserted id.
  Future<String> upsert(RejectTermInput input, {String? id}) async {
    final nowMs = _now().millisecondsSinceEpoch;
    String? targetId = id?.trim();
    if (targetId == null || targetId.isEmpty) {
      final existing = await (_db.select(_db.rejectTerms)
            ..where((t) => t.term.equals(input.term)))
          .getSingleOrNull();
      targetId = existing?.id ?? input.defaultId;
    }
    await _db.into(_db.rejectTerms).insert(
      RejectTermsCompanion.insert(
        id: targetId,
        term: input.term,
        action: input.action,
        createdAtMs: nowMs,
        updatedAtMs: nowMs,
      ),
      onConflict: DoUpdate(
        (_) => RejectTermsCompanion(
          term: Value(input.term),
          action: Value(input.action),
          updatedAtMs: Value(nowMs),
        ),
      ),
    );
    return targetId;
  }

  /// Deletes the row with the given [id]. Returns the number of rows removed
  /// (0 when no match). Existing `suppressed = true` rows are NOT cleared so
  /// operator-driven removals do not silently undo prior block decisions.
  Future<int> deleteById(String id) {
    return (_db.delete(_db.rejectTerms)..where((t) => t.id.equals(id))).go();
  }

  /// Convenience: delete by [term]. Returns number of rows removed.
  Future<int> deleteByTerm(String term) {
    final norm = term.trim().toLowerCase();
    return (_db.delete(_db.rejectTerms)..where((t) => t.term.equals(norm))).go();
  }

  /// Returns the single row matching [id] or null.
  Future<RejectTerm?> getById(String id) {
    return (_db.select(_db.rejectTerms)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }
}
