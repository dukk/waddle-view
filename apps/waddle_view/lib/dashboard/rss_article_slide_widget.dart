import 'dart:async';
import 'dart:typed_data';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';

import '../blob/blob_store.dart';
import '../curator/screen_layout_parse.dart';
import '../curator/screen_program_curator.dart';
import '../persistence/database.dart';
import 'rss_article_slide_timing.dart';

Future<RssArticle?> _loadBestArticleForScreen(
  AppDatabase db,
  ParsedWidgetSpec spec,
) async {
  final feedId = spec.config['feedId'] as String?;
  final q = db.select(db.rssArticles);
  if (feedId != null && feedId.isNotEmpty) {
    q.where((t) => t.feedId.equals(feedId));
  }
  final articles = await (q
        ..orderBy([
          (t) => OrderingTerm.desc(t.publishedAt),
          (t) => OrderingTerm.desc(t.fetchedAt),
        ])
        ..limit(200))
      .get();
  if (articles.isEmpty) {
    return null;
  }

  final imageKeys = <String>{
    for (final a in articles)
      if ((a.imageBlobKey ?? '').trim().isNotEmpty) a.imageBlobKey!.trim(),
  };
  final qualityByBlobKey = <String, int>{};
  if (imageKeys.isNotEmpty) {
    final blobs = await (db.select(db.blobMetadata)
          ..where((t) => t.blobKey.isIn(imageKeys.toList())))
        .get();
    for (final b in blobs) {
      qualityByBlobKey[b.blobKey] = b.bytes;
    }
  }

  articles.sort((a, b) {
    final aKey = (a.imageBlobKey ?? '').trim();
    final bKey = (b.imageBlobKey ?? '').trim();
    final aScore = aKey.isEmpty ? 0 : (qualityByBlobKey[aKey] ?? 0);
    final bScore = bKey.isEmpty ? 0 : (qualityByBlobKey[bKey] ?? 0);
    if (aScore != bScore) {
      return bScore.compareTo(aScore);
    }
    if (a.publishedAt != b.publishedAt) {
      return b.publishedAt.compareTo(a.publishedAt);
    }
    return b.fetchedAt.compareTo(a.fetchedAt);
  });
  return articles.first;
}

Future<Uint8List?> _loadArticleImageBytes(
  AppDatabase db,
  BlobStore blobs,
  RssArticle article,
) async {
  final key = article.imageBlobKey;
  if (key == null || key.isEmpty) {
    return null;
  }
  final meta = await (db.select(db.blobMetadata)
        ..where((t) => t.blobKey.equals(key)))
      .getSingleOrNull();
  if (meta == null) {
    return null;
  }
  final raw = await blobs.readBytes(BlobRef(meta.relativePath));
  if (raw.isEmpty) {
    return null;
  }
  return Uint8List.fromList(raw);
}

int _cfgInt(Map<String, dynamic> c, String key, int def) {
  final v = c[key];
  if (v is int) {
    return v;
  }
  if (v is double) {
    return v.round();
  }
  return def;
}

double _cfgDouble(Map<String, dynamic> c, String key, double def) {
  final v = c[key];
  if (v is double) {
    return v;
  }
  if (v is int) {
    return v.toDouble();
  }
  return def;
}

/// Random RSS article: image beside title + summary; long summaries scroll
/// after a delay. Calls [onReportDesiredDwell] once metrics are known.
class RssArticleSlideWidget extends StatefulWidget {
  const RssArticleSlideWidget({
    super.key,
    required this.db,
    required this.blobs,
    required this.slide,
    required this.spec,
    required this.theme,
    required this.onReportDesiredDwell,
  });

  final AppDatabase db;
  final BlobStore blobs;
  final ResolvedSlide slide;
  final ParsedWidgetSpec spec;
  final ThemeData theme;
  final void Function(int desiredDwellMs) onReportDesiredDwell;

  @override
  State<RssArticleSlideWidget> createState() => _RssArticleSlideWidgetState();
}

class _RssArticleSlideWidgetState extends State<RssArticleSlideWidget> {
  static const _scrollableEpsilon = 8.0;

  RssArticle? _article;
  Uint8List? _imageBytes;
  bool _loading = true;
  final ScrollController _scroll = ScrollController();
  Timer? _scrollDelayTimer;
  bool _dwellReported = false;
  bool _scrollScheduled = false;
  bool _scrollMetricsHookStarted = false;
  bool _plainDwellHookStarted = false;

  late final int _scrollDelayMs;
  late final int _trailingHoldMs;
  late final double _scrollPps;
  late final int _minReadMs;
  late final double _imageFraction;

  @override
  void initState() {
    super.initState();
    final c = widget.spec.config;
    _scrollDelayMs = _cfgInt(c, 'scrollDelayMs', 2500);
    _trailingHoldMs = _cfgInt(c, 'trailingHoldMs', 2000);
    _scrollPps = _cfgDouble(c, 'scrollPixelsPerSecond', 48);
    _minReadMs = _cfgInt(c, 'minReadMs', 8000);
    _imageFraction = _cfgDouble(c, 'imagePanelFraction', 0.39).clamp(0.2, 0.55);
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    final article = await _loadBestArticleForScreen(widget.db, widget.spec);
    Uint8List? bytes;
    if (article != null) {
      bytes = await _loadArticleImageBytes(widget.db, widget.blobs, article);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _article = article;
      _imageBytes = bytes;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _scrollDelayTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _reportDwellNoScrollMetrics() {
    if (!mounted || _dwellReported) {
      return;
    }
    final desired = desiredDwellMsForRssArticle(
      baseDwellMs: widget.slide.dwellMs,
      minReadMs: _minReadMs,
      summaryScrollable: false,
      scrollDelayMs: _scrollDelayMs,
      trailingHoldMs: _trailingHoldMs,
      maxScrollExtent: 0,
      scrollPixelsPerSecond: _scrollPps,
    );
    _dwellReported = true;
    widget.onReportDesiredDwell(desired);
  }

  void _scheduleMetricsHook() {
    if (!mounted || _article == null || _dwellReported || _scrollMetricsHookStarted) {
      return;
    }
    _scrollMetricsHookStarted = true;

    void tick() {
      if (!mounted || _article == null || _dwellReported) {
        return;
      }
      if (!_scroll.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) => tick());
        return;
      }

      final extent = _scroll.position.maxScrollExtent;
      final summaryScrollable = extent > _scrollableEpsilon;
      final desired = desiredDwellMsForRssArticle(
        baseDwellMs: widget.slide.dwellMs,
        minReadMs: _minReadMs,
        summaryScrollable: summaryScrollable,
        scrollDelayMs: _scrollDelayMs,
        trailingHoldMs: _trailingHoldMs,
        maxScrollExtent: summaryScrollable ? extent : 0,
        scrollPixelsPerSecond: _scrollPps,
      );

      _dwellReported = true;
      widget.onReportDesiredDwell(desired);

      if (summaryScrollable && !_scrollScheduled) {
        _scrollScheduled = true;
        _scrollDelayTimer?.cancel();
        _scrollDelayTimer = Timer(Duration(milliseconds: _scrollDelayMs), () {
          if (!mounted || !_scroll.hasClients) {
            return;
          }
          final ms = scrollAnimationDurationMs(
            maxScrollExtent: _scroll.position.maxScrollExtent,
            pixelsPerSecond: _scrollPps,
          );
          unawaited(
            _scroll.animateTo(
              _scroll.position.maxScrollExtent,
              duration: Duration(milliseconds: ms < 200 ? 200 : ms),
              curve: Curves.easeInOut,
            ),
          );
        });
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => tick());
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    final article = _article;
    if (article == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          'No news articles yet',
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
      );
    }

    final summary = article.summary?.trim() ?? '';
    final title = article.title.trim();
    if (title.isEmpty && summary.isEmpty) {
      if (!_plainDwellHookStarted) {
        _plainDwellHookStarted = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _reportDwellNoScrollMetrics();
        });
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          'Article has no title or summary',
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
      );
    }

    if (summary.isEmpty) {
      if (!_plainDwellHookStarted) {
        _plainDwellHookStarted = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _reportDwellNoScrollMetrics();
        });
      }
    } else if (!_scrollMetricsHookStarted) {
      _scheduleMetricsHook();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        if (!w.isFinite || !h.isFinite || w <= 0 || h <= 0) {
          return const SizedBox.shrink();
        }
        final imageW = (w * _imageFraction).clamp(120.0, w * 0.55);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SizedBox(
            width: w,
            height: h,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: imageW,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.4),
                      ),
                      color: theme.colorScheme.surfaceContainerHigh,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: _imageBytes != null
                          ? Image.memory(
                              _imageBytes!,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                              errorBuilder: (context, error, stackTrace) =>
                                  _imagePlaceholder(theme),
                            )
                          : _imagePlaceholder(theme),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (title.isNotEmpty)
                        Text(
                          title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (title.isNotEmpty && summary.isNotEmpty)
                        const SizedBox(height: 12),
                      Expanded(
                        child: summary.isEmpty
                            ? const SizedBox.shrink()
                            : Scrollbar(
                                controller: _scroll,
                                thumbVisibility: true,
                                child: SingleChildScrollView(
                                  key: const Key('rss_article_summary_scroll'),
                                  controller: _scroll,
                                  child: Text(
                                    summary,
                                    style: theme.textTheme.bodyLarge,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _imagePlaceholder(ThemeData theme) {
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          size: 56,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}
