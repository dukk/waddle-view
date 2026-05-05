import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../blob/blob_store.dart';
import '../curator/screen_layout_parse.dart';
import '../curator/screen_program_curator.dart';
import '../persistence/database.dart';
import 'dashboard_viewport_scope.dart';
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
  Uint8List? _imageBytes;
  bool _loading = true;
  final ScrollController _scroll = ScrollController();
  Timer? _scrollDelayTimer;
  bool _dwellReported = false;
  bool _scrollScheduled = false;
  bool _scrollMetricsHookStarted = false;
  bool _plainDwellHookStarted = false;
  double _viewportScale = 1.0;

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
    Uint8List? bytes;
    if (article != null) {
      bytes = await loadRssArticleImageBytes(widget.db, widget.blobs, article);
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
      scrollPixelsPerSecond: _scrollPps * _viewportScale,
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

    final article = _article;
    if (article == null) {
      return Padding(
        padding: EdgeInsets.only(bottom: 12 * s),
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
        padding: EdgeInsets.only(bottom: 12 * s),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Article has no title or summary',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            _articleLinkQr(theme, s, article.link),
          ],
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
        final imageW =
            (w * _imageFraction).clamp(120.0 * s, w * 0.55);
        final imagePanel = SizedBox(
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
              child: _imageBytes != null
                  ? Image.memory(
                      _imageBytes!,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (context, error, stackTrace) =>
                          _imagePlaceholder(theme, s),
                    )
                  : _imagePlaceholder(theme, s),
            ),
          ),
        );
        final gap = SizedBox(width: 20 * s);
        final textPanel = Expanded(
          key: const Key('rss_article_text_column'),
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
                SizedBox(height: 12 * s),
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
              _articleLinkQr(theme, s, article.link),
            ],
          ),
        );
        return Padding(
          padding: EdgeInsets.only(bottom: 12 * s),
          child: SizedBox(
            width: w,
            height: h,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _imageOnRight
                  ? <Widget>[textPanel, gap, imagePanel]
                  : <Widget>[imagePanel, gap, textPanel],
            ),
          ),
        );
      },
    );
  }

  static Widget _imagePlaceholder(ThemeData theme, double s) {
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          size: 56 * s,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  /// QR encoding the article URL for phone cameras. Omits when [link] is empty.
  static Widget _articleLinkQr(ThemeData theme, double s, String link) {
    final url = link.trim();
    if (url.isEmpty) {
      return const SizedBox.shrink();
    }
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: EdgeInsets.only(top: 10 * s),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8 * s),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(6 * s),
            child: QrImageView(
              key: const Key('rss_article_link_qr'),
              data: url,
              version: QrVersions.auto,
              size: 88 * s,
              gapless: true,
            ),
          ),
        ),
      ),
    );
  }
}
