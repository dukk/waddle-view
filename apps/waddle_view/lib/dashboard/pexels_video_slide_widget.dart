import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show CustomExpression, OrderingTerm;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../blob/blob_store.dart';
import '../curator/screen_layout_parse.dart';
import '../curator/screen_program_curator.dart';
import '../persistence/database.dart';
import 'dashboard_viewport_scope.dart';

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
  VideoPlayerController? _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    _controller?.dispose();
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
      final controller = VideoPlayerController.file(file);
      await controller.initialize();
      await controller.setLooping(loop);
      await controller.setVolume(unmuted ? 1.0 : 0.0);
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
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
    final c = _controller!;
    return Center(
      child: AspectRatio(
        aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
        child: VideoPlayer(c),
      ),
    );
  }
}
