import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:waddle_shared/blob/blob_store.dart';
import 'package:waddle_shared/blob/display_blob_read.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/display_overlay_falling_images_settings.dart';

/// Occasionally drops a random uploaded image and rocks it while falling.
class FallingImagesOverlay extends StatefulWidget {
  const FallingImagesOverlay({
    super.key,
    required this.settings,
    required this.blobs,
    required this.db,
  });

  final FallingImagesScheduleSettings settings;
  final BlobStore blobs;
  final AppDatabase db;

  @override
  State<FallingImagesOverlay> createState() => _FallingImagesOverlayState();
}

class _FallingSprite {
  _FallingSprite({
    required this.id,
    required this.blobKey,
    required this.startXFraction,
    required this.size,
    required this.rockPhase,
    required this.startedAt,
  });

  final int id;
  final String blobKey;
  final double startXFraction;
  final double size;
  final double rockPhase;
  final DateTime startedAt;
}

class _FallingImagesOverlayState extends State<FallingImagesOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  final _sprites = <_FallingSprite>[];
  final _imageBytes = <String, Uint8List>{};
  final _pendingLoads = <String>{};
  final _rand = math.Random();
  Timer? _spawnTimer;
  Size _viewport = Size.zero;
  int _nextSpriteId = 0;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(days: 1),
    )..addListener(() {
        if (mounted) {
          setState(_pruneFinishedSprites);
        }
      })
      ..repeat();
    _scheduleNextSpawn();
    unawaited(_preloadKeys(widget.settings.imageBlobKeys));
  }

  @override
  void didUpdateWidget(covariant FallingImagesOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings.dropIntervalSec != widget.settings.dropIntervalSec) {
      _spawnTimer?.cancel();
      _scheduleNextSpawn();
    }
    if (oldWidget.settings.imageBlobKeys.join('\u241e') !=
        widget.settings.imageBlobKeys.join('\u241e')) {
      unawaited(_preloadKeys(widget.settings.imageBlobKeys));
    }
  }

  @override
  void dispose() {
    _spawnTimer?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  void _scheduleNextSpawn() {
    final base = widget.settings.dropIntervalSec.toDouble();
    final delaySec = base * (0.75 + _rand.nextDouble() * 0.5);
    _spawnTimer = Timer(
      Duration(milliseconds: (delaySec * 1000).round()),
      () {
        if (!mounted) {
          return;
        }
        _maybeSpawn();
        _scheduleNextSpawn();
      },
    );
  }

  void _maybeSpawn() {
    final keys = widget.settings.imageBlobKeys;
    if (keys.isEmpty || _viewport == Size.zero) {
      return;
    }
    final key = keys[_rand.nextInt(keys.length)];
    final size = _viewport.shortestSide * (0.08 + _rand.nextDouble() * 0.08);
    _sprites.add(
      _FallingSprite(
        id: _nextSpriteId++,
        blobKey: key,
        startXFraction: 0.08 + _rand.nextDouble() * 0.84,
        size: size.clamp(48.0, 220.0),
        rockPhase: _rand.nextDouble() * math.pi * 2,
        startedAt: DateTime.now(),
      ),
    );
    unawaited(_ensureImageLoaded(key));
  }

  void _pruneFinishedSprites() {
    if (_viewport == Size.zero) {
      return;
    }
    final fallPxPerSec =
        widget.settings.fallSpeed * _viewport.height;
    final now = DateTime.now();
    _sprites.removeWhere((s) {
      final elapsed =
          now.difference(s.startedAt).inMilliseconds / 1000.0;
      final y = elapsed * fallPxPerSec;
      return y > _viewport.height + s.size;
    });
  }

  Future<void> _preloadKeys(List<String> keys) async {
    for (final key in keys) {
      await _ensureImageLoaded(key);
    }
  }

  Future<void> _ensureImageLoaded(String blobKey) async {
    if (_imageBytes.containsKey(blobKey) || _pendingLoads.contains(blobKey)) {
      return;
    }
    _pendingLoads.add(blobKey);
    final row = await (widget.db.select(widget.db.blobMetadata)
          ..where((t) => t.blobKey.equals(blobKey)))
        .getSingleOrNull();
    if (row == null) {
      _pendingLoads.remove(blobKey);
      return;
    }
    final read = await readDisplayBlobBytes(
      widget.blobs,
      BlobRef(row.relativePath),
    );
    if (read.isOk && mounted) {
      setState(() {
        _imageBytes[blobKey] = read.bytes!;
      });
    }
    _pendingLoads.remove(blobKey);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = Size(constraints.maxWidth, constraints.maxHeight);
        final fallPxPerSec =
            widget.settings.fallSpeed * _viewport.height;
        final now = DateTime.now();

        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            for (final sprite in _sprites)
              _buildSprite(sprite, fallPxPerSec, now),
          ],
        );
      },
    );
  }

  Widget _buildSprite(
    _FallingSprite sprite,
    double fallPxPerSec,
    DateTime now,
  ) {
    final bytes = _imageBytes[sprite.blobKey];
    if (bytes == null) {
      return const SizedBox.shrink();
    }
    final elapsed =
        now.difference(sprite.startedAt).inMilliseconds / 1000.0;
    final y = elapsed * fallPxPerSec;
    final rock = math.sin(elapsed * 2.4 + sprite.rockPhase) * sprite.size * 0.22;
    final x = sprite.startXFraction * _viewport.width + rock - sprite.size / 2;
    final tilt = math.sin(elapsed * 3.1 + sprite.rockPhase) * 0.18;

    return Positioned(
      key: ValueKey('falling_sprite_${sprite.id}'),
      left: x,
      top: y - sprite.size,
      width: sprite.size,
      height: sprite.size,
      child: Transform.rotate(
        angle: tilt,
        child: Image.memory(
          bytes,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}
