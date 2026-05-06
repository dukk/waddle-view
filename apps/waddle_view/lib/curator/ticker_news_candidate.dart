import 'package:meta/meta.dart';

/// One RSS row used to build curated marquee items.
@immutable
class TickerNewsCandidate {
  const TickerNewsCandidate({
    required this.feedId,
    required this.feedName,
    required this.title,
    this.summary,
    this.categoryIconName,
    required this.publishedAtMs,
  });

  final String feedId;
  /// Feed channel label for `[…]` when prefixes are enabled (from RSS `channel` title when available).
  final String feedName;
  final String title;
  /// Plain-text excerpt when stored on the article row (nullable).
  final String? summary;
  final String? categoryIconName;
  final int publishedAtMs;

  DateTime get publishedAt =>
      DateTime.fromMillisecondsSinceEpoch(publishedAtMs, isUtc: true);
}
