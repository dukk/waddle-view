import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../persistence/tables.dart';

/// Stable primary key for a row in [News].
String newsArticleId(String sourceType, String sourceId, String stableItemKey) {
  final h = sha256.convert(
    utf8.encode('$sourceType\x00$sourceId\x00$stableItemKey'),
  );
  return h.toString();
}

/// Legacy RSS-only id (source type `rss`).
String rssArticleId(String feedId, String stableItemKey) =>
    newsArticleId(kNewsSourceTypeRss, feedId, stableItemKey);
