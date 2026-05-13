import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../blob/blob_store.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import '../../../curator/screen_program_curator.dart';
import 'package:waddle_shared/persistence/database.dart';
import '../../content_category_slide_header.dart';
import '../../dashboard_viewport_scope.dart';
import 'rss_article_load.dart';
import 'rss_article_slide_timing.dart';

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

bool _cfgBool(Map<String, dynamic> c, String key, bool def) {
  final v = c[key];
  if (v is bool) {
    return v;
  }
  if (v is int) {
    return v != 0;
  }
  if (v is String) {
    final n = v.trim().toLowerCase();
    if (n == '1' || n == 'true' || n == 'yes' || n == 'on') {
      return true;
    }
    if (n == '0' || n == 'false' || n == 'no' || n == 'off') {
      return false;
    }
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
  RssArticleImageLoad _imageLoad = const RssArticleImageLoad.absent();
  bool _loading = true;
  final ScrollController _scroll = ScrollController();
  Timer? _scrollDelayTimer;
  bool _dwellReported = false;
  bool _scrollScheduled = false;
  bool _scrollMetricsHookStarted = false;
  bool _plainDwellHookStarted = false;
  int _scrollMetricsAttempts = 0;
  double _viewportScale = 1.0;
  String? _headerCategoryId;
  String? _sourceLabel;

  late final int _scrollDelayMs;
  late final int _trailingHoldMs;
  late final double _scrollPps;
  late final int _minReadMs;
  late final double _imageFraction;
  late final bool _imageOnRight;

  @override
  void initState() {
    super.initState();
    final c = widget.spec.config;
    _scrollDelayMs = _cfgInt(c, 'scrollDelayMs', 2500);
    _trailingHoldMs = _cfgInt(c, 'trailingHoldMs', 2000);
    _scrollPps = _cfgDouble(c, 'scrollPixelsPerSecond', 48);
    _minReadMs = _cfgInt(c, 'minReadMs', 8000);
    _imageFraction = _cfgDouble(c, 'imagePanelFraction', 0.39).clamp(0.2, 0.55);
    _imageOnRight = _cfgBool(c, 'imageOnRight', false);
    final slideCat =
        widget.slide.randomChoices[ScreenProgramCurator.rssScreenCategoryChoiceKey];
    if (slideCat != null && slideCat.isNotEmpty) {
      _headerCategoryId = slideCat;
    }
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    final article = await loadRssArticleForSlideChoice(
      widget.db,
      widget.spec,
      widget.slide,
      widget.spec.choiceKey,
      const {},
    );
    RssArticleImageLoad load = const RssArticleImageLoad.absent();
    if (article != null) {
      load = await loadRssArticleImage(widget.db, widget.blobs, article);
    }
    final cat = await resolveRssDisplayCategoryId(
      widget.db,
      widget.slide,
      article,
    );
    final sourceLabel = await resolveRssArticleSourceLabel(widget.db, article);
    if (!mounted) {
      return;
    }
    setState(() {
      _article = article;
      _imageLoad = load;
      _headerCategoryId = cat ?? _headerCategoryId;
      _sourceLabel = sourceLabel;
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
      scrollPixelsPerSecond: _scrollPps * _viewportScale,
    );
    _dwellReported = true;
    widget.onReportDesiredDwell(desired);
  }

  void _scheduleMetricsHook() {
    if (!mounted ||
        _article == null ||
        _dwellReported ||
        _scrollMetricsHookStarted) {
      return;
    }
    _scrollMetricsHookStarted = true;
    _scrollMetricsAttempts = 0;

    void tick() {
      if (!mounted || _article == null || _dwellReported) {
        return;
      }
      if (!_scroll.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) => tick());
        return;
      }

      final summaryText = _article!.summary?.trim() ?? '';
      var extent = _scroll.position.maxScrollExtent;
      var summaryScrollable = extent > _scrollableEpsilon;
      // First frame(s) can report zero extent before the summary [Text] finishes
      // layout; retry briefly when the copy is long enough that scroll is likely.
      if (!summaryScrollable &&
          summaryText.length > 200 &&
          _scrollMetricsAttempts < 24) {
        _scrollMetricsAttempts++;
        WidgetsBinding.instance.addPostFrameCallback((_) => tick());
        return;
      }
      final desired = desiredDwellMsForRssArticle(
        baseDwellMs: widget.slide.dwellMs,
        minReadMs: _minReadMs,
        summaryScrollable: summaryScrollable,
        scrollDelayMs: _scrollDelayMs,
        trailingHoldMs: _trailingHoldMs,
        maxScrollExtent: summaryScrollable ? extent : 0,
        scrollPixelsPerSecond: _scrollPps * _viewportScale,
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
            pixelsPerSecond: _scrollPps * _viewportScale,
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
    final s = DashboardViewportScope.scaleOf(context);
    _viewportScale = s;
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

    final article = _article;
    if (article == null) {
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

    final summary = article.summary?.trim() ?? '';
    final title = article.title.trim();
    if (title.isEmpty && summary.isEmpty) {
      if (!_plainDwellHookStarted) {
        _plainDwellHookStarted = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _reportDwellNoScrollMetrics();
        });
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _categoryHeader(theme),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24 * s, 20 * s, 24 * s, 16 * s),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Article has no title or summary',
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  _articleLinkQr(theme, s, article.link, standalone: true),
                ],
              ),
            ),
          ),
        ],
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _categoryHeader(theme),
            Expanded(
              child: LayoutBuilder(
                builder: (context, inner) {
                  final iw = inner.maxWidth;
                  final ih = inner.maxHeight;
                  if (!iw.isFinite || !ih.isFinite || iw <= 0 || ih <= 0) {
                    return const SizedBox.shrink();
                  }
                  return _rssArticleRowLayout(
                    theme: theme,
                    s: s,
                    w: iw,
                    h: ih,
                    article: article,
                    summary: summary,
                    title: title,
                    sourceLabel: _sourceLabel,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _rssArticleRowLayout({
    required ThemeData theme,
    required double s,
    required double w,
    required double h,
    required RssArticle article,
    required String summary,
    required String title,
    required String? sourceLabel,
  }) {
    final hasImage = _imageLoad.bytes != null;
    final imageW = (w * _imageFraction).clamp(120.0 * s, w * 0.55);
    final imagePanel = hasImage
        ? SizedBox(
            key: const Key('rss_article_image_panel'),
            width: imageW,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12 * s),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.4),
                ),
                color: theme.colorScheme.surfaceContainerHigh,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11 * s),
                child: Image.memory(
                  _imageLoad.bytes!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (context, error, stackTrace) =>
                      _imagePlaceholder(
                        theme,
                        s,
                        blobReadFailed: false,
                        useNewsIcon:
                            widget.slide.randomChoices['${widget.spec.choiceKey}_imageMode'] ==
                            'icon',
                      ),
                ),
              ),
            ),
          )
        : const SizedBox.shrink();
    final gap = SizedBox(width: 20 * s);
    final textPanel = Expanded(
      key: const Key('rss_article_text_column'),
      child: Padding(
        padding: EdgeInsets.fromLTRB(18 * s, 16 * s, 18 * s, 14 * s),
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
            if (title.isNotEmpty &&
                sourceLabel != null &&
                sourceLabel.trim().isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 6 * s),
                child: Text(
                  sourceLabel,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (title.isNotEmpty &&
                (summary.isNotEmpty || article.link.trim().isNotEmpty))
              SizedBox(height: 18 * s),
            Expanded(
              child: _summaryAndOptionalQrRow(
                theme: theme,
                s: s,
                summary: summary,
                link: article.link,
              ),
            ),
          ],
        ),
      ),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: 12 * s),
      child: SizedBox(
        width: w,
        height: h,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: hasImage
              ? (_imageOnRight
                    ? <Widget>[textPanel, gap, imagePanel]
                    : <Widget>[imagePanel, gap, textPanel])
              : <Widget>[textPanel],
        ),
      ),
    );
  }

  Widget _summaryAndOptionalQrRow({
    required ThemeData theme,
    required double s,
    required String summary,
    required String link,
  }) {
    final url = link.trim();
    if (url.isEmpty) {
      if (summary.isEmpty) {
        return const SizedBox.shrink();
      }
      return Scrollbar(
        controller: _scroll,
        thumbVisibility: true,
        child: SingleChildScrollView(
          key: const Key('rss_article_summary_scroll'),
          controller: _scroll,
          child: Padding(
            padding: EdgeInsets.only(bottom: 6 * s),
            child: Text(
              summary,
              style: theme.textTheme.bodyLarge,
            ),
          ),
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _articleLinkQr(theme, s, link),
        SizedBox(width: 12 * s),
        Expanded(
          child: summary.isEmpty
              ? const SizedBox.shrink()
              : Scrollbar(
                  controller: _scroll,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    key: const Key('rss_article_summary_scroll'),
                    controller: _scroll,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 6 * s),
                      child: Text(
                        summary,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  static Widget _imagePlaceholder(
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
          size: 56 * s,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  /// QR encoding the article URL for phone cameras. Omits when [link] is empty.
  ///
  /// When [standalone] is true (e.g. no body text), the code is right-aligned
  /// with top padding. When false, the caller places this at the **start** of
  /// a [Row] under the title so the summary sits to the right and wraps there.
  static Widget _articleLinkQr(
    ThemeData theme,
    double s,
    String link, {
    bool standalone = false,
  }) {
    final url = link.trim();
    if (url.isEmpty) {
      return const SizedBox.shrink();
    }
    const qrLogical = 176.0;
    final innerPad = 14 * s;
    final box = Padding(
      padding: EdgeInsets.all(6 * s),
      child: DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8 * s),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(innerPad),
        child: QrImageView(
          key: const Key('rss_article_link_qr'),
          data: url,
          version: QrVersions.auto,
          size: qrLogical * s,
          padding: EdgeInsets.all(4 * s),
          gapless: true,
        ),
      ),
      ),
    );
    if (standalone) {
      return Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: EdgeInsets.only(top: 10 * s),
          child: box,
        ),
      );
    }
    return box;
  }
}
