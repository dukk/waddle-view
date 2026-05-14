import '../persistence/database.dart';
import '../persistence/reject_term_repository.dart';
import '../persistence/tables.dart';
import 'reject_filter.dart';

/// Snapshot of the operator-curated reject list + the chosen mask format.
/// Loaded once per curator refresh (or once at the start of a provider's
/// `collect()` tick) so the cost of querying [RejectTerms] and the
/// [kRejectCensorFormatKvKey] [ConfigKeyValues] row is paid once.
class RejectFilterContext {
  const RejectFilterContext({
    required this.terms,
    required this.format,
  });

  /// Empty context — convenient for tests and as a fallback when the
  /// repository / KV cannot be read.
  const RejectFilterContext.empty()
    : terms = const <RejectFilterTerm>[],
      format = CensorFormat.asterisksFull;

  final List<RejectFilterTerm> terms;
  final CensorFormat format;

  bool get isEmpty => terms.isEmpty;

  /// Convenience wrapper around [censorText].
  String censor(String body) => censorText(body, terms, format);

  /// Convenience wrapper around [hasBlockMatch].
  bool isBlocked(String body) => hasBlockMatch(body, terms);

  /// Convenience wrapper around [hasBlockMatchAny].
  bool isBlockedAny(Iterable<String?> bodies) => hasBlockMatchAny(bodies, terms);

  /// Convenience wrapper around [mediaMatchesAnyTerm].
  bool isMediaRejected({
    required String? photographer,
    required String? altText,
    required Iterable<String?> urls,
  }) => mediaMatchesAnyTerm(
    photographer: photographer,
    altText: altText,
    urls: urls,
    terms: terms,
  );

  /// Loads the live filter from [db]: every [RejectTerms] row plus the
  /// [kRejectCensorFormatKvKey] mask format. Falls back to defaults on missing
  /// keys.
  static Future<RejectFilterContext> loadFromDb(AppDatabase db) async {
    final terms = await RejectTermRepository(db).snapshotForFilter();
    final fmtRow = await (db.select(db.configKeyValues)
          ..where((t) => t.key.equals(kRejectCensorFormatKvKey)))
        .getSingleOrNull();
    return RejectFilterContext(
      terms: terms,
      format: parseCensorFormatKv(fmtRow?.value),
    );
  }
}
