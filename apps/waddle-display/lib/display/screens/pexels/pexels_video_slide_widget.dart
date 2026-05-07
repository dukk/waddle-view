import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show CustomExpression, OrderingTerm;
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart' as mkv;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../blob/blob_store.dart';
import '../../../curator/screen_layout_parse.dart';
import '../../../curator/screen_program_curator.dart';
import '../../../persistence/database.dart';
import '../../dashboard_viewport_scope.dart';
import 'pexels_attribution_overlay.dart';

Future<Video?> loadPexelsVideoForSlide(
  AppDatabase db,
  ParsedWidgetSpec spec,
  ResolvedSlide slide,
) async {
  final curatedId = slide.randomChoices[spec.choiceKey];
  if (curatedId != null && curatedId.isNotEmpty) {
    return (db.select(db.videos)..where((t) => t.id.equals(curatedId)))
        .getSingleOrNull();
  }
  final categoryId = spec.config['categoryId'] as String?;
  final q = db.select(db.videos);
  if (categoryId != null && categoryId.isNotEmpty) {
    q.where((t) => t.category.equals(categoryId));
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

  Future<File> _materializeVideoFile(Video row) async {
    final meta =
        await (widget.db.select(widget.db.blobMetadata)
              ..where((t) => t.blobKey.equals(row.mediaBlobKey)))
            .getSingleOrNull();
    if (meta == null) {
      throw StateError('missing blob metadata');
    }
    final ref = BlobRef(meta.relativePath);
    final direct = widget.blobs.tryLocalFile(ref);
    if (direct != null) {
      return direct;
    }
    final bytes = await widget.blobs.readBytes(ref);
    if (bytes.isEmpty) {
      throw StateError('empty video bytes');
    }
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/pexels_vid_${row.id}.mp4');
    await f.writeAsBytes(bytes, flush: true);
    return f;
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
      final file = await _materializeVideoFile(row);
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
