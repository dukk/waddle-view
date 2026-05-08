import 'dart:async';

import 'package:drift/drift.dart'
    show CustomExpression, Expression, OrderingTerm;
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart' as mkv;
import 'package:url_launcher/url_launcher.dart';

import '../../../blob/blob_store.dart';
import '../../../curator/screen_layout_parse.dart';
import '../../../curator/screen_program_curator.dart';
import '../../../persistence/database.dart';
import '../../dashboard_viewport_scope.dart';
import 'pexels_attribution_overlay.dart';
import 'pexels_video_materialize.dart';

Future<Video?> loadPexelsVideoForSlide(
  AppDatabase db,
  ParsedWidgetSpec spec,
  ResolvedSlide slide,
) async {
  final curatedId = slide.randomChoices[spec.choiceKey];
  if (curatedId != null && curatedId.isNotEmpty) {
    return (db.select(db.videos)
          ..where(
            (t) => Expression.and([
              t.id.equals(curatedId),
              t.suppressed.equals(false),
            ]),
          ))
        .getSingleOrNull();
  }
  final categoryId = spec.config['categoryId'] as String?;
  final q = db.select(db.videos);
  if (categoryId != null && categoryId.isNotEmpty) {
    q.where(
      (t) => Expression.and([
        t.category.equals(categoryId),
        t.suppressed.equals(false),
      ]),
    );
  } else {
    q.where((t) => t.suppressed.equals(false));
  }
  return (q
        ..orderBy([
          (t) => OrderingTerm(expression: const CustomExpression('random()')),
        ])
        ..limit(1))
      .getSingleOrNull();
}

bool pexelsVideoSlideConfigBool(Map<String, dynamic> c, String key, bool def) {
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

/// Full-bleed Pexels video; autoplays (muted by default for signage).
class PexelsVideoSlideWidget extends StatefulWidget {
  const PexelsVideoSlideWidget({
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
  State<PexelsVideoSlideWidget> createState() => _PexelsVideoSlideWidgetState();
}

class _PexelsVideoSlideWidgetState extends State<PexelsVideoSlideWidget> {
  Video? _row;
  Player? _player;
  mkv.VideoController? _videoController;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    final p = _player;
    _player = null;
    _videoController = null;
    if (p != null) {
      unawaited(p.dispose());
    }
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final c = widget.spec.config;
    final unmuted = pexelsVideoSlideConfigBool(c, 'unmuted', false);
    final loop = pexelsVideoSlideConfigBool(c, 'loop', true);

    try {
      final row = await loadPexelsVideoForSlide(
        widget.db,
        widget.spec,
        widget.slide,
      );
      if (row == null) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = 'No Pexels video available';
          });
        }
        return;
      }
      final file = await materializePexelsVideoFile(widget.db, widget.blobs, row);
      final player = Player();
      final videoController = mkv.VideoController(player);
      await player.setPlaylistMode(
        loop ? PlaylistMode.single : PlaylistMode.none,
      );
      await player.setVolume(unmuted ? 100.0 : 0.0);
      await player.open(Media(Uri.file(file.path).toString()));
      if (!mounted) {
        await player.dispose();
        return;
      }
      setState(() {
        _row = row;
        _player = player;
        _videoController = videoController;
        _loading = false;
      });
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$e';
        });
      }
    }
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
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: widget.theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
      );
    }
    final row = _row!;
    final vc = _videoController!;
    return Stack(
      fit: StackFit.expand,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            if ((w.isFinite && w <= 0) || (h.isFinite && h <= 0)) {
              return const SizedBox.shrink();
            }
            return Center(
              child: mkv.Video(
                controller: vc,
                width: w.isFinite ? w : null,
                height: h.isFinite ? h : null,
                fit: BoxFit.cover,
                controls: null,
              ),
            );
          },
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: PexelsAttributionOverlay(
            photographerName: row.photographerName,
            photographerUrl: row.photographerUrl,
            altText: row.altText,
            theme: widget.theme,
            scale: s,
            onOpenUrl: _openUrl,
          ),
        ),
      ],
    );
  }
}
