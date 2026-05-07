import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../blob/blob_store.dart';
import '../../../curator/screen_layout_parse.dart';
import '../../../curator/screen_program_curator.dart';
import '../../../persistence/database.dart';
import '../../content_category_slide_header.dart';
import '../../dashboard_viewport_scope.dart';
import 'rss_article_load.dart';

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

/// Two RSS articles stacked vertically with each row using a left image panel.
/// Each row uses a **text column** (title,
/// then QR under the title with the summary beside it) next to the image.
/// Curator assigns `'${slot}_rss_article_stack_0'` and `'${slot}_rss_article_stack_1'`.
class RssArticleStackSlideWidget extends StatefulWidget {
  const RssArticleStackSlideWidget({
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
  State<RssArticleStackSlideWidget> createState() =>
      _RssArticleStackSlideWidgetState();
}

class _RssArticleStackSlideWidgetState extends State<RssArticleStackSlideWidget> {
  bool _loading = true;
  bool _dwellReported = false;
  late final int _minReadMs;
  late final double _imageFraction;
  late final double _qrLogical;
  final ScrollController _scroll0 = ScrollController();
  final ScrollController _scroll1 = ScrollController();
  final List<RssArticle?> _articles = <RssArticle?>[null, null];
  final List<String?> _sourceLabels = <String?>[null, null];
  final List<RssArticleImageLoad> _imageLoads = <RssArticleImageLoad>[
    const RssArticleImageLoad.absent(),
    const RssArticleImageLoad.absent(),
  ];
  String? _headerCategoryId;

  @override
  void dispose() {
    _scroll0.dispose();
    _scroll1.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final c = widget.spec.config;
    _minReadMs = _cfgInt(c, 'minReadMs', 10000);
    _imageFraction = _cfgDouble(c, 'imagePanelFraction', 0.34).clamp(0.2, 0.48);
    _qrLogical = _cfgDouble(c, 'qrLogicalSize', 112).clamp(72, 200);
    final slideCat =
        widget.slide.randomChoices[ScreenProgramCurator.rssScreenCategoryChoiceKey];
    if (slideCat != null && slideCat.isNotEmpty) {
      _headerCategoryId = slideCat;
    }
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    final exclude = <String>{};
    final arts = <RssArticle?>[];
    final loads = <RssArticleImageLoad>[];
    final sourceLabels = <String?>[];
    for (var i = 0; i < 2; i++) {
      final key = '${widget.spec.choiceKey}_$i';
      final article = await loadRssArticleForSlideChoice(
        widget.db,
        widget.spec,
        widget.slide,
        key,
        exclude,
      );
      arts.add(article);
      if (article != null) {
        exclude.add(article.id);
        loads.add(
          await loadRssArticleImage(widget.db, widget.blobs, article),
        );
      } else {
        loads.add(const RssArticleImageLoad.absent());
      }
      sourceLabels.add(await resolveRssArticleSourceLabel(widget.db, article));
    }
    String? inferred;
    for (final a in arts) {
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
      _articles[0] = arts[0];
      _articles[1] = arts[1];
      _imageLoads[0] = loads[0];
      _imageLoads[1] = loads[1];
      _sourceLabels[0] = sourceLabels[0];
      _sourceLabels[1] = sourceLabels[1];
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

    final a0 = _articles[0];
    final a1 = _articles[1];
    if (a0 == null && a1 == null) {
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

    final midGap = 10.0 * s;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _categoryHeader(theme),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: 12 * s),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final h = constraints.maxHeight;
                if (!h.isFinite || h <= 0) {
                  return const SizedBox.shrink();
                }
                return Column(
                  children: [
                    Expanded(
                      child: _RssStackArticleRow(
                        key: const Key('rss_article_stack_row_0'),
                        constraints: constraints,
                        article: a0,
                        sourceLabel: _sourceLabels[0],
                        imageLoad: _imageLoads[0],
                        imageOnRight: false,
                        theme: theme,
                        s: s,
                        imageFraction: _imageFraction,
                        qrLogical: _qrLogical,
                        stackIndex: 0,
                        summaryScroll: _scroll0,
                        useNewsIcon:
                            widget.slide.randomChoices['${widget.spec.choiceKey}_0_imageMode'] ==
                            'icon',
                      ),
                    ),
                    SizedBox(height: midGap),
                    Expanded(
                      child: _RssStackArticleRow(
                        key: const Key('rss_article_stack_row_1'),
                        constraints: constraints,
                        article: a1,
                        sourceLabel: _sourceLabels[1],
                        imageLoad: _imageLoads[1],
                        imageOnRight: false,
                        theme: theme,
                        s: s,
                        imageFraction: _imageFraction,
                        qrLogical: _qrLogical,
                        stackIndex: 1,
                        summaryScroll: _scroll1,
                        useNewsIcon:
                            widget.slide.randomChoices['${widget.spec.choiceKey}_1_imageMode'] ==
                            'icon',
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _RssStackArticleRow extends StatelessWidget {
  // Not const: [summaryScroll] is a runtime [ScrollController].
  // ignore: prefer_const_constructors_in_immutables
  _RssStackArticleRow({
    super.key,
    required this.constraints,
    required this.article,
    required this.sourceLabel,
    required this.imageLoad,
    required this.imageOnRight,
    required this.theme,
    required this.s,
    required this.imageFraction,
    required this.qrLogical,
    required this.stackIndex,
    required this.summaryScroll,
    required this.useNewsIcon,
  });

  final BoxConstraints constraints;
  final RssArticle? article;
  final String? sourceLabel;
  final RssArticleImageLoad imageLoad;
  final bool imageOnRight;
  final ThemeData theme;
  final double s;
  final double imageFraction;
  final double qrLogical;
  final int stackIndex;
  final ScrollController summaryScroll;
  final bool useNewsIcon;

  @override
  Widget build(BuildContext context) {
    if (article == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10 * s),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.25),
          ),
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.35,
          ),
        ),
        child: Center(
          child: Text(
            'No article for this slot',
            style: theme.textTheme.titleSmall,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final w = constraints.maxWidth;
    final imageW = (w * imageFraction).clamp(96.0 * s, w * 0.45);
    final gapMain = 14.0 * s;

    final imagePanel = SizedBox(
      key: ValueKey('rss_article_stack_image_$stackIndex'),
      width: imageW,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10 * s),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.4),
          ),
          color: theme.colorScheme.surfaceContainerHigh,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9 * s),
          child: imageLoad.bytes != null
              ? Image.memory(
                  imageLoad.bytes!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (context, error, stackTrace) =>
                      _imagePlaceholder(
                        theme,
                        s,
                        blobReadFailed: false,
                        useNewsIcon: useNewsIcon,
                      ),
                )
              : _imagePlaceholder(
                  theme,
                  s,
                  blobReadFailed: imageLoad.blobReadFailed,
                  useNewsIcon: useNewsIcon,
                ),
        ),
      ),
    );

    final a = article!;
    final title = a.title.trim();
    final source = sourceLabel?.trim() ?? '';
    final summary = a.summary?.trim() ?? '';
    final url = a.link.trim();
    final textBlock = Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 4 * s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title.isNotEmpty)
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            if (title.isNotEmpty && source.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 4 * s),
                child: Text(
                  source,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (title.isNotEmpty && (summary.isNotEmpty || url.isNotEmpty))
              SizedBox(height: 8 * s),
            Expanded(
              child: url.isEmpty
                  ? _stackSummaryBody(
                      theme: theme,
                      s: s,
                      stackIndex: stackIndex,
                      summaryScroll: summaryScroll,
                      title: title,
                      summary: summary,
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _stackLinkQr(
                          theme: theme,
                          s: s,
                          link: a.link,
                          qrLogical: qrLogical,
                          stackIndex: stackIndex,
                        ),
                        SizedBox(width: 10 * s),
                        Expanded(
                          child: _stackSummaryBody(
                            theme: theme,
                            s: s,
                            stackIndex: stackIndex,
                            summaryScroll: summaryScroll,
                            title: title,
                            summary: summary,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );

    final rowChildren = imageOnRight
        ? <Widget>[
            textBlock,
            SizedBox(width: gapMain),
            imagePanel,
          ]
        : <Widget>[
            imagePanel,
            SizedBox(width: gapMain),
            textBlock,
          ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rowChildren,
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
          size: 40 * s,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  static Widget _stackLinkQr({
    required ThemeData theme,
    required double s,
    required String link,
    required double qrLogical,
    required int stackIndex,
  }) {
    final u = link.trim();
    if (u.isEmpty) {
      return const SizedBox.shrink();
    }
    final innerPad = 12 * s;
    return Padding(
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
            key: ValueKey('rss_article_stack_qr_$stackIndex'),
            data: u,
            version: QrVersions.auto,
            size: qrLogical * s,
            padding: EdgeInsets.all(4 * s),
            gapless: true,
          ),
        ),
      ),
    );
  }

  static Widget _stackSummaryBody({
    required ThemeData theme,
    required double s,
    required int stackIndex,
    required ScrollController summaryScroll,
    required String title,
    required String summary,
  }) {
    if (summary.isNotEmpty) {
      return Scrollbar(
        controller: summaryScroll,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: summaryScroll,
          key: ValueKey('rss_article_stack_summary_$stackIndex'),
          child: Padding(
            padding: EdgeInsets.only(bottom: 4 * s),
            child: Text(
              summary,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ),
      );
    }
    if (title.isEmpty && summary.isEmpty) {
      return Center(
        child: Text(
          '—',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
