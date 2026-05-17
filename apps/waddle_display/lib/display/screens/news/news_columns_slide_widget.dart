import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:waddle_shared/blob/blob_store.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import '../../../curator/screen_program_curator.dart';
import 'package:waddle_shared/persistence/database.dart';
import '../../content_category_slide_header.dart';
import '../../dashboard_viewport_scope.dart';
import 'news_load.dart';

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
  const _ColumnArticle(this.article, this.imageLoad, this.sourceLabel);
  final RssArticle? article;
  final NewsImageLoad imageLoad;
  final String? sourceLabel;
}

/// [columnCount] RSS articles in a row: image on top, then title with a link
/// QR placed under it (start-aligned) and the summary beside the QR when
/// [RssArticle.link] is set.
/// Curator assigns [ResolvedSlide.randomChoices] keys
/// `'${slot}_news_columns_0'` … `_2` for three columns.
class NewsColumnsSlideWidget extends StatefulWidget {
  const NewsColumnsSlideWidget({
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
  State<NewsColumnsSlideWidget> createState() =>
      _NewsColumnsSlideWidgetState();
}

class _NewsColumnsSlideWidgetState
    extends State<NewsColumnsSlideWidget> {
  bool _loading = true;
  bool _dwellReported = false;
  late final int _nColumns;
  late final int _minReadMs;
  late final double _qrLogical;
  List<_ColumnArticle> _columns = const [];
  String? _headerCategoryId;

  @override
  void initState() {
    super.initState();
    final slideCat =
        widget.slide.randomChoices[ScreenProgramCurator.rssScreenCategoryChoiceKey];
    if (slideCat != null && slideCat.isNotEmpty) {
      _headerCategoryId = slideCat;
    }
    final c = widget.spec.config;
    _nColumns = _columnCountFromConfig(c);
    _minReadMs = _cfgInt(c, 'minReadMs', 8000);
    _qrLogical = _cfgDouble(c, 'qrLogicalSize', 80).clamp(48, 140);
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
      NewsImageLoad load = const NewsImageLoad.absent();
      if (article != null) {
        exclude.add(article.id);
        load = await loadRssArticleImage(widget.db, widget.blobs, article);
      }
      final sourceLabel = await resolveRssArticleSourceLabel(widget.db, article);
      out.add(_ColumnArticle(article, load, sourceLabel));
    }
    String? inferred;
    for (final col in out) {
      final a = col.article;
      if (a == null) {
        continue;
      }
      inferred = await resolveRssDisplayCategoryId(
        widget.db,
        widget.slide,
        a,
      );
      break;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _columns = out;
      _headerCategoryId = inferred ?? _headerCategoryId;
      _loading = false;
    });
  }

  Widget _categoryHeader(ThemeData theme) {
    return ContentCategorySlideHeader(
      db: widget.db,
      blobs: widget.blobs,
      theme: theme,
      categoryId: _headerCategoryId,
    );
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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _categoryHeader(theme),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(24 * s),
              child: Center(
                child: SizedBox(
                  width: 32 * s,
                  height: 32 * s,
                  child: const CircularProgressIndicator(),
                ),
              ),
            ),
          ),
        ],
      );
    }

    final anyArticle = _columns.any((c) => c.article != null);
    if (!anyArticle) {
      if (!_dwellReported) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _reportDwell());
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _categoryHeader(theme),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24 * s, 20 * s, 24 * s, 16 * s),
              child: Text(
                'No news articles yet',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _categoryHeader(theme),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: 12 * s),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < _columns.length; i++) ...[
                      if (i > 0) SizedBox(width: gap),
                      Expanded(
                        child: _ArticleColumnCard(
                          theme: theme,
                          scale: s,
                          columnIndex: i,
                          qrLogical: _qrLogical,
                          data: _columns[i],
                          useNewsIcon:
                              widget.slide.randomChoices['${widget.spec.choiceKey}_${i}_imageMode'] ==
                              'icon',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ArticleColumnCard extends StatelessWidget {
  const _ArticleColumnCard({
    required this.theme,
    required this.scale,
    required this.columnIndex,
    required this.qrLogical,
    required this.data,
    required this.useNewsIcon,
  });

  final ThemeData theme;
  final double scale;
  final int columnIndex;
  final double qrLogical;
  final _ColumnArticle data;
  final bool useNewsIcon;

  @override
  Widget build(BuildContext context) {
    final article = data.article;
    if (article == null) {
      return const SizedBox.shrink();
    }
    final title = article.title.trim();
    final summary = article.summary?.trim() ?? '';
    final sourceLabel = data.sourceLabel?.trim() ?? '';
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
                          _placeholder(
                            theme,
                            scale,
                            blobReadFailed: false,
                            useNewsIcon: useNewsIcon,
                          ),
                    )
                  : _placeholder(
                      theme,
                      scale,
                      blobReadFailed: data.imageLoad.blobReadFailed,
                      useNewsIcon: useNewsIcon,
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
                if (title.isNotEmpty && sourceLabel.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 4 * scale),
                    child: Text(
                      sourceLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (title.isNotEmpty &&
                    (summary.isNotEmpty || article.link.trim().isNotEmpty))
                  SizedBox(height: 10 * scale),
                Expanded(
                  child: article.link.trim().isEmpty
                      ? _columnSummaryOnly(
                          title: title,
                          summary: summary,
                          theme: theme,
                          scale: scale,
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _columnLinkQr(
                              theme: theme,
                              scale: scale,
                              link: article.link,
                              qrLogical: qrLogical,
                              columnIndex: columnIndex,
                            ),
                            SizedBox(width: 8 * scale),
                            Expanded(
                              child: _columnSummaryOnly(
                                title: title,
                                summary: summary,
                                theme: theme,
                                scale: scale,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static Widget _columnSummaryOnly({
    required String title,
    required String summary,
    required ThemeData theme,
    required double scale,
  }) {
    if (summary.isNotEmpty) {
      return Padding(
        padding: EdgeInsets.only(bottom: 4 * scale),
        child: Text(
          summary,
          style: theme.textTheme.bodySmall,
          maxLines: 6,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }
    if (title.isNotEmpty) {
      return const SizedBox.shrink();
    }
    return Center(
      child: Text(
        '—',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  static Widget _columnLinkQr({
    required ThemeData theme,
    required double scale,
    required String link,
    required double qrLogical,
    required int columnIndex,
  }) {
    final url = link.trim();
    if (url.isEmpty) {
      return const SizedBox.shrink();
    }
    final innerPad = 10 * scale;
    return Padding(
      padding: EdgeInsets.all(6 * scale),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8 * scale),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(innerPad),
          child: QrImageView(
            key: ValueKey('news_columns_qr_$columnIndex'),
            data: url,
            version: QrVersions.auto,
            size: qrLogical * scale,
            padding: EdgeInsets.all(4 * scale),
            gapless: true,
          ),
        ),
      ),
    );
  }

  static Widget _placeholder(
    ThemeData theme,
    double s, {
    required bool blobReadFailed,
    bool useNewsIcon = false,
  }) {
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          blobReadFailed
              ? Icons.no_photography
              : useNewsIcon
              ? Icons.newspaper
              : Icons.image_not_supported_outlined,
          size: 36 * s,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}
