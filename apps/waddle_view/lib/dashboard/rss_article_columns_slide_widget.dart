import 'dart:async';

import 'package:flutter/material.dart';

import '../blob/blob_store.dart';
import '../curator/screen_layout_parse.dart';
import '../curator/screen_program_curator.dart';
import '../persistence/database.dart';
import 'dashboard_viewport_scope.dart';
import 'rss_article_load.dart';

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

int _columnCountFromConfig(Map<String, dynamic> c) {
  final v = c['columnCount'];
  if (v is int) {
    return v.clamp(1, 6);
  }
  if (v is double) {
    return v.round().clamp(1, 6);
  }
  return 3;
}

class _ColumnArticle {
  const _ColumnArticle(this.article, this.imageLoad);
  final RssArticle? article;
  final RssArticleImageLoad imageLoad;
}

/// [columnCount] RSS articles in a row: image on top, title and summary below.
/// Curator assigns [ResolvedSlide.randomChoices] keys
/// `'${slot}_rss_article_columns_0'` … `_2` for three columns.
class RssArticleColumnsSlideWidget extends StatefulWidget {
  const RssArticleColumnsSlideWidget({
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
  State<RssArticleColumnsSlideWidget> createState() =>
      _RssArticleColumnsSlideWidgetState();
}

class _RssArticleColumnsSlideWidgetState
    extends State<RssArticleColumnsSlideWidget> {
  bool _loading = true;
  bool _dwellReported = false;
  late final int _nColumns;
  late final int _minReadMs;
  List<_ColumnArticle> _columns = const [];

  @override
  void initState() {
    super.initState();
    final c = widget.spec.config;
    _nColumns = _columnCountFromConfig(c);
    _minReadMs = _cfgInt(c, 'minReadMs', 8000);
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    final exclude = <String>{};
    final out = <_ColumnArticle>[];
    for (var i = 0; i < _nColumns; i++) {
      final key = '${widget.spec.choiceKey}_$i';
      final article = await loadRssArticleForSlideChoice(
        widget.db,
        widget.spec,
        widget.slide,
        key,
        exclude,
      );
      RssArticleImageLoad load = const RssArticleImageLoad.absent();
      if (article != null) {
        exclude.add(article.id);
        load = await loadRssArticleImage(widget.db, widget.blobs, article);
      }
      out.add(_ColumnArticle(article, load));
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _columns = out;
      _loading = false;
    });
  }

  void _reportDwell() {
    if (!mounted || _dwellReported) {
      return;
    }
    _dwellReported = true;
    final base = widget.slide.dwellMs;
    widget.onReportDesiredDwell(base > _minReadMs ? base : _minReadMs);
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final s = DashboardViewportScope.scaleOf(context);
    if (_loading) {
      return Padding(
        padding: EdgeInsets.all(24 * s),
        child: Center(
          child: SizedBox(
            width: 32 * s,
            height: 32 * s,
            child: const CircularProgressIndicator(),
          ),
        ),
      );
    }

    final anyArticle = _columns.any((c) => c.article != null);
    if (!anyArticle) {
      if (!_dwellReported) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _reportDwell());
      }
      return Padding(
        padding: EdgeInsets.fromLTRB(24 * s, 20 * s, 24 * s, 16 * s),
        child: Text(
          'No news articles yet',
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
      );
    }

    if (!_dwellReported) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reportDwell());
    }

    final gap = 10.0 * s;
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        if (!h.isFinite || h <= 0) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: EdgeInsets.only(bottom: 12 * s),
          child: SizedBox(
            height: h,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < _columns.length; i++) ...[
                  if (i > 0) SizedBox(width: gap),
                  Expanded(
                    child: _ArticleColumnCard(
                      theme: theme,
                      scale: s,
                      data: _columns[i],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ArticleColumnCard extends StatelessWidget {
  const _ArticleColumnCard({
    required this.theme,
    required this.scale,
    required this.data,
  });

  final ThemeData theme;
  final double scale;
  final _ColumnArticle data;

  @override
  Widget build(BuildContext context) {
    final article = data.article;
    if (article == null) {
      return const SizedBox.shrink();
    }
    final title = article.title.trim();
    final summary = article.summary?.trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 16 / 10,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10 * scale),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.35),
              ),
              color: theme.colorScheme.surfaceContainerHigh,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9 * scale),
              child: data.imageLoad.bytes != null
                  ? Image.memory(
                      data.imageLoad.bytes!,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (context, error, stackTrace) =>
                          _placeholder(theme, scale, blobReadFailed: false),
                    )
                  : _placeholder(
                      theme,
                      scale,
                      blobReadFailed: data.imageLoad.blobReadFailed,
                    ),
            ),
          ),
        ),
        SizedBox(height: 12 * scale),
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              14 * scale,
              4 * scale,
              14 * scale,
              10 * scale,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (title.isNotEmpty)
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (title.isNotEmpty && summary.isNotEmpty)
                  SizedBox(height: 10 * scale),
                if (summary.isNotEmpty)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 4 * scale),
                      child: Text(
                        summary,
                        style: theme.textTheme.bodySmall,
                        maxLines: 6,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static Widget _placeholder(
    ThemeData theme,
    double s, {
    required bool blobReadFailed,
  }) {
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          blobReadFailed
              ? Icons.no_photography
              : Icons.image_not_supported_outlined,
          size: 36 * s,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}
