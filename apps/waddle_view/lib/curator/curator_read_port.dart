import 'ticker_news_candidate.dart';

/// Reads domain facts for [DashboardCurator] (no network).
abstract class CuratorReadPort {
  Future<Map<String, String>> loadKeyValuesForCuration();

  /// RSS articles (newest-first from storage), empty if none.
  Future<List<TickerNewsCandidate>> loadNewsCandidatesForTicker();
}
