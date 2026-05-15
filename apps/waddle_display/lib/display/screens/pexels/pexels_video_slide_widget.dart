import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart'
    show CustomExpression, Expression, OrderingTerm;
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart' as mkv;
import 'package:url_launcher/url_launcher.dart';

import 'package:waddle_shared/blob/blob_store.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import '../../../curator/screen_program_curator.dart';
import 'package:waddle_shared/persistence/database.dart';
import '../../dashboard_viewport_scope.dart';
import 'pexels_attribution_overlay.dart';
import 'pexels_video_materialize.dart';
import 'pexels_video_playback.dart';

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
    this.allowPlayback = true,
  });

  final AppDatabase db;
  final BlobStore blobs;
  final ResolvedSlide slide;
  final ParsedWidgetSpec spec;
  final ThemeData theme;

  /// When false (e.g. during carousel slide transition), native video surfaces
  /// are not created so media_kit is not asked to resize textures to 0×0.
  final bool allowPlayback;

  @override
  State<PexelsVideoSlideWidget> createState() => _PexelsVideoSlideWidgetState();
}

class _PexelsVideoSlideWidgetState extends State<PexelsVideoSlideWidget> {
  Video? _row;
  File? _mediaFile;
  bool _loop = true;
  bool _unmuted = false;
  Player? _player;
  mkv.VideoController? _videoController;
  StreamSubscription<String>? _errorSub;
  bool _loading = true;
  String? _error;
  bool _layoutReady = false;
  bool _playbackStarted = false;
  int _playbackRetries = 0;
  int _playbackGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_prepareMedia());
  }

  @override
  void didUpdateWidget(covariant PexelsVideoSlideWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.allowPlayback != widget.allowPlayback) {
      if (widget.allowPlayback) {
        unawaited(_maybeStartPlayback());
      } else {
        unawaited(_teardownPlayback());
      }
    }
  }

  @override
  void dispose() {
    unawaited(_teardownPlayback(disposing: true));
    super.dispose();
  }

  Future<void> _prepareMedia() async {
    final c = widget.spec.config;
    _unmuted = pexelsVideoSlideConfigBool(c, 'unmuted', false);
    _loop = pexelsVideoSlideConfigBool(c, 'loop', true);

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
      if (!mounted) {
        return;
      }
      setState(() {
        _row = row;
        _mediaFile = file;
        _loading = false;
      });
      await _maybeStartPlayback();
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$e';
        });
      }
    }
  }

  void _reportLayoutSize(double width, double height) {
    final ready = pexelsVideoLayoutSizeReady(width, height);
    if (ready == _layoutReady) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (ready == _layoutReady) {
        return;
      }
      setState(() {
        _layoutReady = ready;
      });
      if (ready) {
        unawaited(_maybeStartPlayback());
      }
    });
  }

  Future<void> _maybeStartPlayback() async {
    if (!mounted ||
        !widget.allowPlayback ||
        !_layoutReady ||
        _playbackStarted ||
        _mediaFile == null ||
        _row == null ||
        _error != null) {
      return;
    }
    await _startPlayback();
  }

  Future<void> _startPlayback() async {
    final file = _mediaFile;
    if (file == null || _playbackStarted) {
      return;
    }
    final generation = ++_playbackGeneration;
    _playbackStarted = true;
    try {
      final player = Player();
      final videoController = mkv.VideoController(player);
      _errorSub?.cancel();
      _errorSub = player.stream.error.listen(
        (message) => unawaited(_onPlaybackError(message)),
      );
      await player.setPlaylistMode(
        _loop ? PlaylistMode.single : PlaylistMode.none,
      );
      await player.setVolume(_unmuted ? 100.0 : 0.0);
      await player.open(Media(Uri.file(file.path).toString()));
      if (!mounted || generation != _playbackGeneration) {
        await player.dispose();
        return;
      }
      setState(() {
        _player = player;
        _videoController = videoController;
      });
    } on Object catch (e) {
      _playbackStarted = false;
      await _errorSub?.cancel();
      _errorSub = null;
      if (mounted && generation == _playbackGeneration) {
        setState(() {
          _error = '$e';
        });
      }
    }
  }

  Future<void> _onPlaybackError(String message) async {
    if (!mounted || !widget.allowPlayback) {
      return;
    }
    if (_playbackRetries >= kPexelsVideoMaxPlaybackRetries) {
      if (mounted) {
        setState(() {
          _error = message;
        });
      }
      return;
    }
    _playbackRetries++;
    final delay = pexelsVideoRetryDelay(_playbackRetries);
    await Future<void>.delayed(delay);
    if (!mounted || !widget.allowPlayback) {
      return;
    }
    await _restartPlayback();
  }

  Future<void> _restartPlayback() async {
    await _teardownPlayback(keepMedia: true);
    if (!mounted || _mediaFile == null) {
      return;
    }
    await _maybeStartPlayback();
  }

  Future<void> _teardownPlayback({
    bool disposing = false,
    bool keepMedia = false,
  }) async {
    _playbackGeneration++;
    _playbackStarted = false;
    await _errorSub?.cancel();
    _errorSub = null;
    final player = _player;
    _player = null;
    _videoController = null;
    if (player != null) {
      try {
        await player.stop();
      } on Object {
        // Best-effort before dispose.
      }
      try {
        await player.dispose();
      } on Object {
        // Native teardown may race with texture release during transitions.
      }
    }
    if (!disposing && mounted && !keepMedia) {
      setState(() {});
    } else if (!disposing && mounted) {
      setState(() {});
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
    final vc = _videoController;
    return Stack(
      fit: StackFit.expand,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            _reportLayoutSize(w, h);
            if (vc == null ||
                !widget.allowPlayback ||
                !pexelsVideoLayoutSizeReady(w, h)) {
              return ColoredBox(
                color: widget.theme.colorScheme.surface,
              );
            }
            return Center(
              child: mkv.Video(
                key: const Key('pexels_video_surface'),
                controller: vc,
                width: w,
                height: h,
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
