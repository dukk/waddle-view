import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../blob/blob_store.dart';
import '../../../curator/photo_collage_curation.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import '../../../curator/screen_program_curator.dart';
import '../../dashboard_viewport_scope.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'pexels_slide_media.dart';

class _CollageCell {
  const _CollageCell({this.row, this.bytes});

  final Photo? row;
  final Uint8List? bytes;
}

/// Multi-tile Pexels collage; slot images come from
/// `slide.randomChoices['${spec.choiceKey}_$index']`.
class PexelsPhotoCollageSlideWidget extends StatefulWidget {
  const PexelsPhotoCollageSlideWidget({
    super.key,
    required this.db,
    required this.blobs,
    required this.slide,
    required this.spec,
    required this.theme,
  });

  final AppDatabase db;
  final BlobStore blobs;
  final ResolvedSlide slide;
  final ParsedWidgetSpec spec;
  final ThemeData theme;

  @override
  State<PexelsPhotoCollageSlideWidget> createState() =>
      _PexelsPhotoCollageSlideWidgetState();
}

class _PexelsPhotoCollageSlideWidgetState
    extends State<PexelsPhotoCollageSlideWidget> {
  String _templateId = kCollageTemplateNineSquareAsymmetric;
  List<_CollageCell> _cells = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    final raw =
        (widget.spec.config['template'] as String?)?.trim() ??
        kCollageTemplateNineSquareAsymmetric;
    final templateId = kKnownCollageTemplateIds.contains(raw)
        ? raw
        : kCollageTemplateNineSquareAsymmetric;
    final n = collageSlotCount(templateId);
    final choiceKey = widget.spec.choiceKey;
    final loaded = await Future.wait(
      List.generate(n, (i) async {
        final id = widget.slide.randomChoices['${choiceKey}_$i'];
        final row = await loadPhotoByCuratedId(widget.db, id);
        Uint8List? bytes;
        if (row != null) {
          bytes = await loadPhotoBlobBytes(widget.db, widget.blobs, row);
        }
        return _CollageCell(row: row, bytes: bytes);
      }),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _templateId = templateId;
      _cells = loaded;
      _loading = false;
    });
  }

  Future<void> _openUrl(String url) async {
    final u = Uri.tryParse(url.trim());
    if (u == null || !(u.hasScheme && (u.isScheme('http') || u.isScheme('https')))) {
      return;
    }
    await launchUrl(u, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final s = DashboardViewportScope.scaleOf(context);
    if (_loading) {
      return Center(
        child: SizedBox(
          width: 36 * s,
          height: 36 * s,
          child: CircularProgressIndicator(
            strokeWidth: 3 * s,
            color: widget.theme.colorScheme.primary,
          ),
        ),
      );
    }
    if (_cells.isEmpty) {
      return Center(
        child: Text(
          'No collage template',
          style: widget.theme.textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        return _buildLayoutForTemplate(
          templateId: _templateId,
          cells: _cells,
          scale: s,
          maxWidth: constraints.maxWidth,
          maxHeight: constraints.maxHeight,
        );
      },
    );
  }

  Widget _buildLayoutForTemplate({
    required String templateId,
    required List<_CollageCell> cells,
    required double scale,
    required double maxWidth,
    required double maxHeight,
  }) {
    switch (templateId) {
      case kCollageTemplateNineSquareAsymmetric:
        return _nineSquareGrid(cells, scale);
      case kCollageTemplateElevenSymmetricHub:
        return _elevenHubLayout(cells, scale);
      case kCollageTemplateNineMixedGrid:
        return _nineMixedLayout(cells, scale);
      case kCollageTemplateNineDynamicHub:
        return _nineDynamicHubLayout(cells, scale, maxWidth, maxHeight);
      case kCollageTemplateTwelveCircleBand:
        return _twelveBandLayout(cells, scale);
      default:
        return _nineSquareGrid(cells, scale);
    }
  }

  Widget _cellTile(_CollageCell cell, double scale, {BoxFit fit = BoxFit.cover}) {
    final row = cell.row;
    final bytes = cell.bytes;
    if (row == null || bytes == null) {
      return ColoredBox(
        color: widget.theme.colorScheme.surfaceContainerHighest,
        child: Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            color: widget.theme.colorScheme.onSurfaceVariant,
            size: 28 * scale,
          ),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.memory(bytes, fit: fit, gaplessPlayback: true),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Material(
            color: Colors.black.withValues(alpha: 0.45),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 6 * scale, vertical: 4 * scale),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (row.photographerName.isNotEmpty)
                    Text(
                      row.photographerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: widget.theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (row.photographerUrl.isNotEmpty)
                    InkWell(
                      onTap: () => _openUrl(row.photographerUrl),
                      child: Text(
                        row.photographerUrl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: widget.theme.textTheme.labelSmall?.copyWith(
                          color: Colors.lightBlueAccent,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _bordered(Widget child) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 0.5),
      ),
      child: child,
    );
  }

  Widget _nineSquareGrid(List<_CollageCell> cells, double scale) {
    return Column(
      children: List.generate(3, (r) {
        return Expanded(
          child: Row(
            children: List.generate(3, (c) {
              final i = r * 3 + c;
              final cell = i < cells.length ? cells[i] : const _CollageCell();
              return Expanded(child: _bordered(_cellTile(cell, scale)));
            }),
          ),
        );
      }),
    );
  }

  Widget _elevenHubLayout(List<_CollageCell> cells, double scale) {
    Widget cellAt(int i) {
      final cell = i < cells.length ? cells[i] : const _CollageCell();
      return _bordered(_cellTile(cell, scale));
    }

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Column(
            children: [
              Expanded(child: cellAt(0)),
              Expanded(child: cellAt(1)),
            ],
          ),
        ),
        Expanded(
          flex: 6,
          child: Column(
            children: [
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Expanded(child: cellAt(2)),
                    Expanded(child: cellAt(3)),
                    Expanded(child: cellAt(4)),
                  ],
                ),
              ),
              Expanded(flex: 5, child: cellAt(5)),
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Expanded(child: cellAt(6)),
                    Expanded(child: cellAt(7)),
                    Expanded(child: cellAt(8)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: Column(
            children: [
              Expanded(child: cellAt(9)),
              Expanded(child: cellAt(10)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _nineMixedLayout(List<_CollageCell> cells, double scale) {
    Widget cellAt(int i) {
      final cell = i < cells.length ? cells[i] : const _CollageCell();
      return _bordered(_cellTile(cell, scale));
    }

    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: cellAt(0)),
              Expanded(child: cellAt(1)),
              Expanded(flex: 2, child: cellAt(2)),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(child: cellAt(3)),
              Expanded(child: cellAt(4)),
              Expanded(child: cellAt(5)),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(child: cellAt(6)),
              Expanded(child: cellAt(7)),
              Expanded(child: cellAt(8)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _nineDynamicHubLayout(
    List<_CollageCell> cells,
    double scale,
    double w,
    double h,
  ) {
    Widget cellAt(int i) {
      final cell = i < cells.length ? cells[i] : const _CollageCell();
      return _bordered(_cellTile(cell, scale));
    }

    final side = w * 0.14;
    final edgeH = h * 0.12;
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned(
          left: side,
          top: edgeH,
          right: side,
          bottom: edgeH,
          child: cellAt(4),
        ),
        Positioned(
          left: 0,
          top: h * 0.22,
          width: side,
          height: h * 0.4,
          child: cellAt(0),
        ),
        Positioned(
          right: 0,
          top: h * 0.22,
          width: side,
          height: h * 0.4,
          child: cellAt(1),
        ),
        Positioned(
          left: w * 0.18,
          top: 0,
          right: w * 0.18,
          height: edgeH,
          child: cellAt(2),
        ),
        Positioned(
          left: w * 0.18,
          bottom: 0,
          right: w * 0.18,
          height: edgeH,
          child: cellAt(3),
        ),
        Positioned(
          left: 0,
          top: 0,
          width: w * 0.2,
          height: h * 0.2,
          child: cellAt(5),
        ),
        Positioned(
          right: 0,
          top: 0,
          width: w * 0.2,
          height: h * 0.2,
          child: cellAt(6),
        ),
        Positioned(
          left: 0,
          bottom: 0,
          width: w * 0.2,
          height: h * 0.2,
          child: cellAt(7),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          width: w * 0.2,
          height: h * 0.2,
          child: cellAt(8),
        ),
      ],
    );
  }

  Widget _twelveBandLayout(List<_CollageCell> cells, double scale) {
    Widget cellAt(int i) {
      final cell = i < cells.length ? cells[i] : const _CollageCell();
      return _bordered(_cellTile(cell, scale));
    }

    return Column(
      children: [
        Expanded(
          flex: 3,
          child: Row(
            children: [
              Expanded(child: cellAt(0)),
              Expanded(child: cellAt(1)),
              Expanded(child: cellAt(2)),
              Expanded(child: cellAt(3)),
              Expanded(child: cellAt(4)),
            ],
          ),
        ),
        Expanded(
          flex: 4,
          child: Row(
            children: [
              Expanded(flex: 2, child: cellAt(5)),
              Expanded(flex: 3, child: cellAt(6)),
              Expanded(flex: 2, child: cellAt(7)),
            ],
          ),
        ),
        Expanded(
          flex: 3,
          child: Row(
            children: [
              Expanded(child: cellAt(8)),
              Expanded(child: cellAt(9)),
              Expanded(child: cellAt(10)),
              Expanded(child: cellAt(11)),
            ],
          ),
        ),
      ],
    );
  }
}
