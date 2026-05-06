import 'ticker_news_candidate.dart';

class CurrentWeatherTickerData {
  const CurrentWeatherTickerData({
    required this.locationName,
    this.temperatureC,
    this.description,
  });

  final String locationName;
  final double? temperatureC;
  final String? description;

  String toTickerBody() {
    final parts = <String>[];
    if (temperatureC != null) {
      parts.add('${temperatureC!.round()}\u00B0');
    }
    final trimmedDescription = description?.trim() ?? '';
    if (trimmedDescription.isNotEmpty) {
      parts.add(trimmedDescription);
    }
    final summary = parts.join(' · ');
    if (summary.isEmpty) {
      return locationName;
    }
    return '$locationName: $summary';
  }
}

/// Reads domain facts for [DashboardCurator] (no network).
abstract class CuratorReadPort {
  Future<Map<String, String>> loadKeyValuesForCuration();

  /// RSS articles (newest-first from storage), empty if none.
  Future<List<TickerNewsCandidate>> loadNewsCandidatesForTicker();

  /// Current weather snapshot for ticker, null when unavailable.
  Future<CurrentWeatherTickerData?> loadCurrentWeatherForTicker();
}
