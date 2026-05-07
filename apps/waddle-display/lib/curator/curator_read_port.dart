import 'package:meta/meta.dart';

import 'ticker_news_candidate.dart';

/// One row from [TickerDefinitions] for marquee curation.
@immutable
class TickerDefinitionForCuration {
  const TickerDefinitionForCuration({
    required this.id,
    required this.tickerType,
    required this.enabled,
    required this.frequencyWeight,
    required this.sortOrder,
    this.configKey,
  });

  final String id;
  /// `time`, `weather`, `news`, `quote`, `stocks`, or `custom`.
  final String tickerType;
  final bool enabled;
  final int frequencyWeight;
  final int sortOrder;
  /// When [tickerType] is `custom`, optional `ticker.marquee.*` key; when null,
  /// all extra marquee keys are included (same as legacy “custom” bucket).
  final String? configKey;
}

@immutable
class WeatherGovAlertTickerItem {
  const WeatherGovAlertTickerItem({
    required this.body,
    required this.sourceId,
  });

  final String body;
  final String sourceId;
}

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

/// One enabled symbol and optional latest quote for marquee `stocks` slots.
typedef StockTickerRowForMarquee = ({
  String symbolId,
  String symbol,
  String displayName,
  double? currentPrice,
  double? percentChange,
});

/// Reads domain facts for [DashboardCurator] (no network).
abstract class CuratorReadPort {
  Future<Map<String, String>> loadKeyValuesForCuration();

  /// RSS articles (newest-first from storage), empty if none.
  Future<List<TickerNewsCandidate>> loadNewsCandidatesForTicker();

  /// Current weather snapshot for ticker, null when unavailable.
  Future<CurrentWeatherTickerData?> loadCurrentWeatherForTicker();

  /// Active NWS alerts for enabled weather locations (deduped by NWS id).
  Future<List<WeatherGovAlertTickerItem>> loadWeatherGovAlertsForTicker();

  /// All ticker definition rows, ordered by [TickerDefinitionForCuration.sortOrder]
  /// then id.
  Future<List<TickerDefinitionForCuration>> loadTickerDefinitionsForCuration();

  /// Enabled [StockSymbols] rows with optional [StockQuotes], ordered by symbol.
  Future<List<StockTickerRowForMarquee>> loadStockRowsForTicker();
}
