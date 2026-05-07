import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../blob/blob_store.dart';
import '../../curator/photo_collage_curation.dart';
import '../../curator/screen_layout_parse.dart';
import '../../curator/screen_program_curator.dart';
import '../../persistence/database.dart';
import '../../dashboard_viewport_scope.dart';
import 'pexels_attribution_overlay.dart';
import 'pexels_slide_media.dart';

/// Multi-photo collage driven by [kKnownCollageTemplateIds] (`config.template`).
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
  static const _nineMixedRects = <Rect>[
    Rect.fromLTWH(0, 0, 0.19, 0.30),
    Rect.fromLTWH(0.19, 0, 0.19, 0.30),
    Rect.fromLTWH(0.38, 0, 0.30, 0.30),
    Rect.fromLTWH(0.70, 0, 0.30, 0.62),
    Rect.fromLTWH(0, 0.30, 0.38, 0.70),
    Rect.fromLTWH(0.38, 0.30, 0.30, 0.34),
    Rect.fromLTWH(0.38, 0.66, 0.30, 0.34),
    Rect.fromLTWH(0.70, 0.64, 0.145, 0.36),
    Rect.fromLTWH(0.855, 0.64, 0.145, 0.36),
  ];

  static const _nineDynamicRects = <Rect>[
    Rect.fromLTWH(0, 0, 0.22, 0.45),
    Rect.fromLTWH(0, 0.48, 0.22, 0.52),
    Rect.fromLTWH(0.78, 0, 0.22, 0.45),
    Rect.fromLTWH(0.78, 0.48, 0.22, 0.52),
    Rect.fromLTWH(0.24, 0.18, 0.52, 0.52),
    Rect.fromLTWH(0.24, 0, 0.25, 0.16),
    Rect.fromLTWH(0.51, 0, 0.25, 0.16),
    Rect.fromLTWH(0.24, 0.72, 0.25, 0.28),
    Rect.fromLTWH(0.51, 0.72, 0.25, 0.28),
  ];

  List<Uint8List?> _bytes = [];
  Photo? _attribRow;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  String get _template =>
      (widget.spec.config['template'] as String?)?.trim() ??
      kCollageTemplateNineSquareAsymmetric;

  int get _n => collageSlotCount(_template);

  Future<void> _bootstrap() async {
    final n = _n;
    final keys = widget.spec.choiceKey;
    final rows = <Photo?>[];
    final bytes = <Uint8List?>[];
    for (var i = 0; i < n; i++) {
      final id = widget.slide.randomChoices['${keys}_$i'];
      final row = await loadPhotoByCuratedId(widget.db, id);
      rows.add(row);
      if (row != null) {
        bytes.add(await loadPhotoBlobBytes(widget.db, widget.blobs, row));
      } else {
        bytes.add(null);
      }
    }
    if (!mounted) {
      return;
    }
    Photo? attrib;
    switch (_template) {
      case kCollageTemplateElevenSymmetricHub:
      case kCollageTemplateNineDynamicHub:
        attrib = rows.length > 5 ? rows[5] : null;
        break;
      case kCollageTemplateTwelveCircleBand:
        attrib = rows.length > 6 ? rows[6] : null;
        break;
      default:
        attrib = rows.cast<Photo?>().firstWhere(
          (e) => e != null,
          orElse: () => null,
        );
    }
    setState(() {
      _bytes = bytes;
      _attribRow = attrib;
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

  double _gapPx(BuildContext context) => 3 * DashboardViewportScope.scaleOf(context);

  Widget _tile(Uint8List? b) {
    final Widget img;
    if (b == null) {
      img = ColoredBox(color: Colors.grey.shade900);
    } else {
      img = Image.memory(
        b,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: img,
    );
  }

  List<Widget> _cells(BuildContext context) {
    final g = _gapPx(context);
    return List<Widget>.generate(_bytes.length, (i) {
      return Padding(
        padding: EdgeInsets.all(g * 0.5),
        child: _tile(_bytes[i]),
      );
    });
  }

  Widget _nineSquare(List<Widget> c) {
    assert(c.length == 9);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 2,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: c[0]),
                    Expanded(child: c[1]),
                  ],
                ),
              ),
              Expanded(flex: 5, child: c[6]),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: c[2]),
              Expanded(child: c[3]),
              Expanded(child: c[4]),
            ],
          ),
        ),
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 5, child: c[5]),
              Expanded(
                flex: 2,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: c[7]),
                    Expanded(child: c[8]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _elevenHub(List<Widget> c) {
    assert(c.length == 11);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: c[0]),
              Expanded(child: c[1]),
            ],
          ),
        ),
        Expanded(
          flex: 9,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 2,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: c[2]),
                    Expanded(child: c[3]),
                    Expanded(child: c[4]),
                  ],
                ),
              ),
              Expanded(flex: 5, child: c[5]),
              Expanded(
                flex: 2,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: c[6]),
                    Expanded(child: c[7]),
                    Expanded(child: c[8]),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: c[9]),
              Expanded(child: c[10]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stackRects(List<Widget> c, List<Rect> rects) {
    assert(c.length == rects.length);
    return LayoutBuilder(
      builder: (context, bc) {
        final w = bc.maxWidth;
        final h = bc.maxHeight;
        return Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: Colors.grey.shade300),
            for (var i = 0; i < c.length; i++)
              Positioned(
                left: rects[i].left * w,
                top: rects[i].top * h,
                width: rects[i].width * w,
                height: rects[i].height * h,
                child: c[i],
              ),
          ],
        );
      },
    );
  }

  Widget _twelveBand(List<Widget> c, BuildContext context) {
    assert(c.length == 12);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 2,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < 5; i++) Expanded(child: c[i]),
            ],
          ),
        ),
        Expanded(
          flex: 5,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 5, child: c[5]),
              Expanded(
                flex: 4,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: ClipOval(child: c[6]),
                  ),
                ),
              ),
              Expanded(flex: 5, child: c[7]),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < 4; i++) Expanded(child: c[8 + i]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _body(BuildContext context) {
    final c = _cells(context);
    switch (_template) {
      case kCollageTemplateNineSquareAsymmetric:
        return _nineSquare(c);
      case kCollageTemplateElevenSymmetricHub:
        return _elevenHub(c);
      case kCollageTemplateNineMixedGrid:
        return _stackRects(c, _nineMixedRects);
      case kCollageTemplateNineDynamicHub:
        return _stackRects(c, _nineDynamicRects);
      case kCollageTemplateTwelveCircleBand:
        return _twelveBand(c, context);
      default:
        return Center(
          child: Text(
            'Unknown collage template: $_template',
            style: widget.theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        );
    }
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
    if (_n <= 0) {
      return Center(
        child: Text(
          'Invalid collage template',
          style: widget.theme.textTheme.titleLarge,
        ),
      );
    }
    final attrib = _attribRow;
    return ColoredBox(
      color: Colors.white,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Padding(
            padding: EdgeInsets.all(_gapPx(context)),
            child: _body(context),
          ),
          if (attrib != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: PexelsAttributionOverlay(
                photographerName: attrib.photographerName,
                photographerUrl: attrib.photographerUrl,
                altText: attrib.altText,
                theme: widget.theme,
                scale: s,
                onOpenUrl: _openUrl,
              ),
            ),
        ],
      ),
    );
  }
}
