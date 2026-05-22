import 'package:flutter/foundation.dart';

/// Optional RSS article segments for rich marquee text (source / title / summary).
@immutable
class TickerRssSegments {
  const TickerRssSegments({
    required this.sourceTitle,
    required this.articleTitle,
    required this.summary,
    required this.showSource,
    this.sourceIconName,
  });

  /// Feed label without brackets (shown as `[sourceTitle]` when [showSource]).
  final String sourceTitle;
  final String? sourceIconName;
  final String articleTitle;
  final String summary;
  final bool showSource;

  @override
  bool operator ==(Object other) =>
      other is TickerRssSegments &&
      other.sourceTitle == sourceTitle &&
      other.sourceIconName == sourceIconName &&
      other.articleTitle == articleTitle &&
      other.summary == summary &&
      other.showSource == showSource;

  @override
  int get hashCode =>
      Object.hash(sourceTitle, sourceIconName, articleTitle, summary, showSource);
}

/// Live clock rendering config for marquee `time` items.
@immutable
class TickerTimeDisplay {
  const TickerTimeDisplay({
    required this.timeFormatPreset,
    this.timeZone,
    this.labelPrefix,
  });

  final String timeFormatPreset;
  final String? timeZone;
  final String? labelPrefix;

  @override
  bool operator ==(Object other) =>
      other is TickerTimeDisplay &&
      other.timeFormatPreset == timeFormatPreset &&
      other.timeZone == timeZone &&
      other.labelPrefix == labelPrefix;

  @override
  int get hashCode => Object.hash(timeFormatPreset, timeZone, labelPrefix);
}

/// Structured stock line for colored marquee rendering.
@immutable
class TickerStockDisplay {
  const TickerStockDisplay({
    required this.symbol,
    required this.displayName,
    this.currentPrice,
    this.percentChange,
  });

  final String symbol;
  final String displayName;
  final double? currentPrice;
  final double? percentChange;

  @override
  bool operator ==(Object other) =>
      other is TickerStockDisplay &&
      other.symbol == symbol &&
      other.displayName == displayName &&
      other.currentPrice == currentPrice &&
      other.percentChange == percentChange;

  @override
  int get hashCode =>
      Object.hash(symbol, displayName, currentPrice, percentChange);
}

/// Weather icon hint for marquee (OpenWeather-style code from blob key).
@immutable
class TickerWeatherDisplay {
  const TickerWeatherDisplay({this.iconCode});

  final String? iconCode;

  @override
  bool operator ==(Object other) =>
      other is TickerWeatherDisplay && other.iconCode == iconCode;

  @override
  int get hashCode => iconCode.hashCode;
}

/// One unit in the bottom marquee (after curation from domain data).
@immutable
class TickerItem {
  const TickerItem({
    required this.kind,
    required this.body,
    this.sourceId,
    this.rss,
    this.articleId,
    this.timeDisplay,
    this.stockDisplay,
    this.weatherDisplay,
  });

  final String kind;
  final String body;
  final String? sourceId;

  /// When set (typically [kind] `news` from RSS), the marquee renders [rss]
  /// with distinct styles; [body] remains the plain-text equivalent for
  /// deduplication and APIs.
  final TickerRssSegments? rss;

  /// [RssArticles.id] when [kind] is `news` from a concrete article row.
  final String? articleId;

  /// When set ([kind] `time`), marquee renders a live updating clock.
  final TickerTimeDisplay? timeDisplay;

  /// When set ([kind] `stocks`), marquee applies up/down colors to the change.
  final TickerStockDisplay? stockDisplay;

  /// When set ([kind] `weather`), marquee picks icon from [iconCode].
  final TickerWeatherDisplay? weatherDisplay;

  @override
  bool operator ==(Object other) =>
      other is TickerItem &&
      other.kind == kind &&
      other.body == body &&
      other.sourceId == sourceId &&
      other.rss == rss &&
      other.articleId == articleId &&
      other.timeDisplay == timeDisplay &&
      other.stockDisplay == stockDisplay &&
      other.weatherDisplay == weatherDisplay;

  @override
  int get hashCode => Object.hash(
        kind,
        body,
        sourceId,
        rss,
        articleId,
        timeDisplay,
        stockDisplay,
        weatherDisplay,
      );
}
