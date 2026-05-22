import 'package:meta/meta.dart';
import 'package:waddle_shared/curation/reject_filter_context.dart';
import 'package:waddle_shared/display/display_weather_temperature_unit_kv.dart';

import 'ticker_item.dart';
import 'ticker_news_candidate.dart';

/// Preloaded Quoterism lines for ticker curation.
@immutable
class QuoterismTickerMarqueeData {
  const QuoterismTickerMarqueeData({
    this.items = const [],
    this.categoryIdsByQuoteId = const {},
  });

  final List<TickerItem> items;
  final Map<String, Set<String>> categoryIdsByQuoteId;
}

/// One row from [TickerTapes] for marquee curation.
@immutable
class TickerTapeForCuration {
  const TickerTapeForCuration({
    required this.id,
    required this.tickerType,
    required this.frequencyWeight,
    required this.sortOrder,
    this.configJson = '{}',
  });

  final String id;
  /// `time`, `weather`, `news`, `stocks`, `static_text`, or `plugin`.
  final String tickerType;
  final int frequencyWeight;
  final int sortOrder;
  /// JSON object for the tape (e.g. `text` for static_text, plugin options).
  final String configJson;
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
    required this.locationId,
    required this.locationName,
    this.temperatureC,
    this.description,
    this.iconCode,
  });

  final String locationId;
  final String locationName;
  final double? temperatureC;
  final String? description;
  final String? iconCode;

  String toTickerBody({required String temperatureUnit}) {
    final parts = <String>[];
    if (temperatureC != null) {
      final displayTemp = formatWeatherTemperatureCelsius(
        temperatureC,
        unit: temperatureUnit,
      );
      parts.add('$displayTemp${weatherTemperatureSuffix(temperatureUnit)}');
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

  /// Weather snapshots keyed by [InterestsLocations.id].
  Future<Map<String, CurrentWeatherTickerData>> loadWeatherByLocationIdForTicker();

  /// First available weather row (legacy convenience).
  Future<CurrentWeatherTickerData?> loadCurrentWeatherForTicker();

  /// Active NWS alerts for enabled weather locations (deduped by NWS id).
  Future<List<WeatherGovAlertTickerItem>> loadWeatherGovAlertsForTicker();

  /// All ticker tape rows, ordered by [TickerTapeForCuration.sortOrder]
  /// then id.
  Future<List<TickerTapeForCuration>> loadTickerTapesForCuration();

  /// Enabled [InterestsStockSymbols] rows with optional [StockQuotes], ordered by symbol.
  Future<List<StockTickerRowForMarquee>> loadStockRowsForTicker();

  /// Quoterism quote ticker lines and per-quote category ids.
  Future<QuoterismTickerMarqueeData> loadQuoterismQuotesForTicker();

  /// Snapshot of the operator-curated reject list + chosen censor format.
  Future<RejectFilterContext> loadRejectFilterContext();
}
