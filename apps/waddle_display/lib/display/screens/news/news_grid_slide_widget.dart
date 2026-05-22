import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:waddle_shared/blob/blob_store.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import 'package:waddle_shared/persistence/database.dart';

import '../../../curator/screen_program_curator.dart';
import '../../../theme/display_theme.dart';
import '../../content_category_slide_header.dart';
import '../../dashboard_viewport_scope.dart';
import 'news_config.dart';
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

class _GridCellData {
  const _GridCellData(this.article, this.imageLoad, this.sourceLabel);
  final NewsArticle? article;
  final NewsImageLoad imageLoad;
  final String? sourceLabel;
}

/// Six RSS articles in a fixed 3×2 grid: image, headline, and source per cell.
/// Optional summary when [showSummary] is true. QR overlays on the left or right
/// edge of the image when configured.
///
/// Curator assigns [ResolvedSlide.randomChoices] keys
/// `'${slot}_news_grid_0'` … `_5` (row-major).
class NewsGridSlideWidget extends StatefulWidget {
  const NewsGridSlideWidget({
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
  State<NewsGridSlideWidget> createState() => _NewsGridSlideWidgetState();
}

class _NewsGridSlideWidgetState extends State<NewsGridSlideWidget> {
  bool _loading = true;
  bool _dwellReported = false;
  late final int _minReadMs;
  late final double _qrLogical;
  late final String _qrMode;
  late final BoxFit _imageFit;
  late final bool _showSummary;
  List<_GridCellData> _cells = const [];
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
    _minReadMs = _cfgInt(c, 'minReadMs', 8000);
    _qrLogical = _cfgDouble(c, 'qrLogicalSize', 52).clamp(36, 72);
    _qrMode = readNewsGridQrMode(c);
    _imageFit = readNewsImageFit(c);
    _showSummary = readNewsGridShowSummary(c);
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    final exclude = <String>{};
    final out = <_GridCellData>[];
    for (var i = 0; i < kNewsGridSlotCount; i++) {
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
      out.add(_GridCellData(article, load, sourceLabel));
    }
    String? inferred;
    for (final cell in out) {
      final a = cell.article;
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
      _cells = out;
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

  Widget _gridRow(ThemeData theme, double s, int rowIndex) {
    final gap = 8.0 * s;
    final start = rowIndex * 3;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var col = 0; col < 3; col++) ...[
          if (col > 0) SizedBox(width: gap),
          Expanded(
            child: _GridCell(
              key: Key('news_grid_cell_${start + col}'),
              theme: theme,
              scale: s,
              cellIndex: start + col,
              qrLogical: _qrLogical,
              qrMode: _qrMode,
              imageFit: _imageFit,
              showSummary: _showSummary,
              data: _cells[start + col],
              useNewsIcon:
                  widget.slide.randomChoices[
                      '${widget.spec.choiceKey}_${start + col}_imageMode'] ==
                  'icon',
            ),
          ),
        ],
      ],
    );
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

    final anyArticle = _cells.any((c) => c.article != null);
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

    final rowGap = 8.0 * s;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _categoryHeader(theme),
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(12 * s, 4 * s, 12 * s, 10 * s),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _gridRow(theme, s, 0)),
                SizedBox(height: rowGap),
                Expanded(child: _gridRow(theme, s, 1)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GridCell extends StatelessWidget {
  const _GridCell({
    super.key,
    required this.theme,
    required this.scale,
    required this.cellIndex,
    required this.qrLogical,
    required this.qrMode,
    required this.imageFit,
    required this.showSummary,
    required this.data,
    required this.useNewsIcon,
  });

  final ThemeData theme;
  final double scale;
  final int cellIndex;
  final double qrLogical;
  final String qrMode;
  final BoxFit imageFit;
  final bool showSummary;
  final _GridCellData data;
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
    final link = article.link.trim();
    final showQr = newsQrVisible(qrMode) &&
        link.isNotEmpty &&
        (newsQrImageOverlayLeft(qrMode) || newsQrImageOverlayRight(qrMode));

    Widget imageChild;
    if (data.imageLoad.bytes != null) {
      imageChild = Image.memory(
        data.imageLoad.bytes!,
        fit: imageFit,
        gaplessPlayback: true,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => _placeholder(
          theme,
          scale,
          blobReadFailed: false,
          useNewsIcon: useNewsIcon,
        ),
      );
    } else {
      imageChild = _placeholder(
        theme,
        scale,
        blobReadFailed: data.imageLoad.blobReadFailed,
        useNewsIcon: useNewsIcon,
      );
    }

    if (showQr) {
      final qr = _gridLinkQr(
        theme: theme,
        scale: scale,
        link: link,
        qrLogical: qrLogical,
        cellIndex: cellIndex,
      );
      imageChild = Stack(
        fit: StackFit.expand,
        children: [
          imageChild,
          if (newsQrImageOverlayLeft(qrMode))
            Positioned(
              left: 4 * scale,
              top: 0,
              bottom: 0,
              child: Align(
                alignment: Alignment.centerLeft,
                child: qr,
              ),
            ),
          if (newsQrImageOverlayRight(qrMode))
            Positioned(
              right: 4 * scale,
              top: 0,
              bottom: 0,
              child: Align(
                alignment: Alignment.centerRight,
                child: qr,
              ),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 3,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8 * scale),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.35),
              ),
              color: theme.slidePanelColor,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7 * scale),
              child: imageChild,
            ),
          ),
        ),
        SizedBox(height: 6 * scale),
        Expanded(
          flex: 2,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4 * scale),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (title.isNotEmpty)
                  Text(
                    title,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (sourceLabel.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 2 * scale),
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
                if (showSummary && summary.isNotEmpty)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: 4 * scale),
                      child: Text(
                        summary,
                        style: theme.textTheme.bodySmall,
                        maxLines: 3,
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

  static Widget _gridLinkQr({
    required ThemeData theme,
    required double scale,
    required String link,
    required double qrLogical,
    required int cellIndex,
  }) {
    final url = link.trim();
    if (url.isEmpty) {
      return const SizedBox.shrink();
    }
    final innerPad = 4 * scale;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6 * scale),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(innerPad),
        child: QrImageView(
          key: ValueKey('news_grid_qr_$cellIndex'),
          data: url,
          version: QrVersions.auto,
          size: qrLogical * scale,
          padding: EdgeInsets.all(2 * scale),
          gapless: true,
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
      color: theme.slidePanelColor,
      child: Center(
        child: Icon(
          blobReadFailed
              ? Icons.no_photography
              : useNewsIcon
              ? Icons.newspaper
              : Icons.image_not_supported_outlined,
          size: 28 * s,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}
