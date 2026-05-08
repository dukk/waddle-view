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

/// One unit in the bottom marquee (after curation from domain data).
@immutable
class TickerItem {
  const TickerItem({
    required this.kind,
    required this.body,
    this.sourceId,
    this.rss,
  });

  final String kind;
  final String body;
  final String? sourceId;

  /// When set (typically [kind] `news` from RSS), the marquee renders [rss]
  /// with distinct styles; [body] remains the plain-text equivalent for
  /// deduplication and APIs.
  final TickerRssSegments? rss;

  @override
  bool operator ==(Object other) =>
      other is TickerItem &&
      other.kind == kind &&
      other.body == body &&
      other.sourceId == sourceId &&
      other.rss == rss;

  @override
  int get hashCode => Object.hash(kind, body, sourceId, rss);
}
