import 'package:webfeed/domain/atom_feed.dart';
import 'package:webfeed/domain/atom_item.dart';
import 'package:webfeed/domain/media/media.dart';
import 'package:webfeed/domain/rss_feed.dart';
import 'package:webfeed/domain/rss_item.dart';
import 'package:webfeed/util/datetime.dart';

import 'rss_text_sanitize.dart';

/// One entry from an RSS 2.0 or Atom feed.
class ParsedFeedEntry {
  const ParsedFeedEntry({
    required this.stableKey,
    required this.title,
    required this.link,
    this.summary,
    required this.publishedAtMs,
    this.imageUrl,
  });

  final String stableKey;
  final String title;
  final String link;
  final String? summary;
  final int publishedAtMs;
  final String? imageUrl;
}

class ParsedFeed {
  const ParsedFeed({this.channelTitle, required this.entries});

  final String? channelTitle;
  final List<ParsedFeedEntry> entries;
}

final _imgSrc = RegExp(
  r'''<img[^>]+src=["']([^"']+)["']''',
  caseSensitive: false,
);

String? _firstImgSrcFromHtml(String? raw) {
  if (raw == null || raw.isEmpty) {
    return null;
  }
  final m = _imgSrc.firstMatch(raw);
  return m?.group(1);
}

String? _imageUrlFromRssItem(RssItem item) {
  final enc = item.enclosure;
  if (enc != null) {
    final t = enc.type?.toLowerCase() ?? '';
    if (t.startsWith('image/') && enc.url != null && enc.url!.isNotEmpty) {
      return enc.url;
    }
  }
  final thumbs = item.media?.thumbnails;
  if (thumbs != null) {
    for (final th in thumbs) {
      if (th.url != null && th.url!.isNotEmpty) {
        return th.url;
      }
    }
  }
  final contents = item.media?.contents;
  if (contents != null) {
    for (final c in contents) {
      final t = c.type?.toLowerCase() ?? '';
      final m = c.medium?.toLowerCase() ?? '';
      if (c.url != null &&
          c.url!.isNotEmpty &&
          (t.startsWith('image/') || m == 'image')) {
        return c.url;
      }
    }
  }
  return _firstImgSrcFromHtml(item.description) ??
      _firstImgSrcFromHtml(item.content?.value);
}

String? _imageUrlFromMedia(Media? media) {
  if (media == null) {
    return null;
  }
  final thumbs = media.thumbnails;
  if (thumbs != null) {
    for (final th in thumbs) {
      if (th.url != null && th.url!.isNotEmpty) {
        return th.url;
      }
    }
  }
  final contents = media.contents;
  if (contents != null) {
    for (final c in contents) {
      final t = c.type?.toLowerCase() ?? '';
      if (c.url != null && c.url!.isNotEmpty && t.startsWith('image/')) {
        return c.url;
      }
    }
  }
  return null;
}

String? _atomLinkHref(AtomItem item) {
  final links = item.links;
  if (links == null || links.isEmpty) {
    return null;
  }
  for (final l in links) {
    if (l.href == null || l.href!.isEmpty) {
      continue;
    }
    if (l.rel == 'alternate') {
      return l.href;
    }
  }
  for (final l in links) {
    if (l.href != null && l.href!.isNotEmpty) {
      return l.href;
    }
  }
  return null;
}

int _publishedMsForAtom(AtomItem item) {
  final u = item.updated;
  if (u != null) {
    return u.millisecondsSinceEpoch;
  }
  final p = parseDateTime(item.published);
  if (p != null) {
    return p.millisecondsSinceEpoch;
  }
  return DateTime.now().millisecondsSinceEpoch;
}

/// Parses RSS 2.0 or Atom; throws if neither.
ParsedFeed parseRssOrAtomXml(String xmlBody) {
  try {
    final rss = RssFeed.parse(xmlBody);
    final entries = <ParsedFeedEntry>[];
    for (final item in rss.items ?? const <RssItem>[]) {
      final guidRaw = item.guid?.trim();
      final linkRaw = item.link?.trim();
      final stable = (guidRaw != null && guidRaw.isNotEmpty)
          ? guidRaw
          : (linkRaw ?? '');
      if (stable.isEmpty) {
        continue;
      }
      var title = sanitizeRssDisplayText(item.title?.trim() ?? '');
      if (title.isEmpty) {
        final fallback =
            (linkRaw != null && linkRaw.isNotEmpty) ? linkRaw : stable;
        title = sanitizeRssDisplayText(fallback);
      }
      final link = sanitizeRssLink(
        (linkRaw != null && linkRaw.isNotEmpty)
            ? linkRaw
            : (rss.link ?? ''),
      );
      if (link.isEmpty) {
        continue;
      }
      if (title.isEmpty) {
        title = sanitizeRssDisplayText(link);
      }
      if (title.isEmpty) {
        continue;
      }
      final pub = item.pubDate ?? DateTime.now();
      entries.add(
        ParsedFeedEntry(
          stableKey: stable,
          title: title,
          link: link,
          summary: sanitizeRssOptional(item.description?.trim()),
          publishedAtMs: pub.millisecondsSinceEpoch,
          imageUrl: _imageUrlFromRssItem(item),
        ),
      );
    }
    final channel = sanitizeRssDisplayText(rss.title?.trim() ?? '');
    return ParsedFeed(
      channelTitle: channel.isEmpty ? null : channel,
      entries: entries,
    );
  } on Object {
    // Fall through to Atom
  }
  final atom = AtomFeed.parse(xmlBody);
  final entries = <ParsedFeedEntry>[];
  for (final item in atom.items ?? const <AtomItem>[]) {
    final idRaw = item.id?.trim();
    final link = _atomLinkHref(item)?.trim();
    final stable = (idRaw != null && idRaw.isNotEmpty)
        ? idRaw
        : (link ?? '');
    if (stable.isEmpty) {
      continue;
    }
    var title = item.title?.trim() ?? '';
    final href = link ?? '';
    if (href.isEmpty) {
      continue;
    }
    final hrefClean = sanitizeRssLink(href);
    if (hrefClean.isEmpty) {
      continue;
    }
    if (title.isEmpty) {
      title = hrefClean;
    }
    title = sanitizeRssDisplayText(title);
    if (title.isEmpty) {
      title = sanitizeRssDisplayText(hrefClean);
    }
    if (title.isEmpty) {
      continue;
    }
    final rawSummary = item.summary?.trim() ?? item.content?.trim();
    entries.add(
      ParsedFeedEntry(
        stableKey: stable,
        title: title,
        link: hrefClean,
        summary: sanitizeRssOptional(rawSummary),
        publishedAtMs: _publishedMsForAtom(item),
        imageUrl: _imageUrlFromMedia(item.media) ??
            _firstImgSrcFromHtml(item.summary) ??
            _firstImgSrcFromHtml(item.content),
      ),
    );
  }
  final atomChannel = sanitizeRssDisplayText(atom.title?.trim() ?? '');
  return ParsedFeed(
    channelTitle: atomChannel.isEmpty ? null : atomChannel,
    entries: entries,
  );
}
