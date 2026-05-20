import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:waddle_display/display/overlay/photo_slideshow_media.dart';
import 'package:waddle_display/display/screens/photo/photo_slide_media.dart';
import 'package:waddle_shared/blob/blob_store.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/display_overlay_photo_slideshow_settings.dart';

/// Cycles random catalog photos at a configured viewport position.
class PhotoSlideshowOverlay extends StatefulWidget {
  const PhotoSlideshowOverlay({
    super.key,
    required this.settings,
    required this.blobs,
    required this.db,
  });

  final PhotoSlideshowOverlaySettings settings;
  final BlobStore blobs;
  final AppDatabase db;

  @override
  State<PhotoSlideshowOverlay> createState() => _PhotoSlideshowOverlayState();
}

class _PhotoSlideshowOverlayState extends State<PhotoSlideshowOverlay> {
  Uint8List? _bytes;
  String _mimeType = '';
  String? _currentPhotoId;
  Timer? _cycleTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_pickAndLoadPhoto());
    _startCycleTimer();
  }

  @override
  void didUpdateWidget(covariant PhotoSlideshowOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings.intervalSec != widget.settings.intervalSec) {
      _startCycleTimer();
    }
    if (oldWidget.settings.toJson().toString() !=
        widget.settings.toJson().toString()) {
      unawaited(_pickAndLoadPhoto());
    }
  }

  @override
  void dispose() {
    _cycleTimer?.cancel();
    super.dispose();
  }

  void _startCycleTimer() {
    _cycleTimer?.cancel();
    _cycleTimer = Timer.periodic(
      Duration(seconds: widget.settings.intervalSec),
      (_) => unawaited(_pickAndLoadPhoto()),
    );
  }

  Future<void> _pickAndLoadPhoto() async {
    if (!widget.settings.isRenderable) {
      if (mounted) {
        setState(() {
          _bytes = null;
          _mimeType = '';
          _currentPhotoId = null;
        });
      }
      return;
    }
    final poolSize = await countPhotosForSlideshow(widget.db, widget.settings);
    String? exclude;
    if (poolSize > 1) {
      exclude = _currentPhotoId;
    }
    final photo = await selectRandomPhotoForSlideshow(
      widget.db,
      widget.settings,
      excludePhotoId: exclude,
    );
    if (!mounted) {
      return;
    }
    if (photo == null) {
      setState(() {
        _bytes = null;
        _mimeType = '';
        _currentPhotoId = null;
      });
      return;
    }
    final meta = await (widget.db.select(widget.db.blobMetadata)
          ..where((t) => t.blobKey.equals(photo.mediaBlobKey)))
        .getSingleOrNull();
    if (!mounted) {
      return;
    }
    final bytes = await loadPhotoBlobBytes(widget.db, widget.blobs, photo);
    if (!mounted) {
      return;
    }
    setState(() {
      _currentPhotoId = photo.id;
      if (bytes != null) {
        _bytes = bytes;
        _mimeType = meta?.mimeType ?? '';
      } else {
        _bytes = null;
        _mimeType = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes == null) {
      return const SizedBox.shrink();
    }
    final settings = widget.settings;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        if (width <= 0 || height <= 0) {
          return const SizedBox.shrink();
        }
        final shortest = width < height ? width : height;
        final imageWidth = settings.scale * shortest;
        final left = settings.x * width;
        final top = settings.y * height;
        Widget image = _buildImageWidget(_bytes!, _mimeType);
        if (settings.opacity < 1.0) {
          image = Opacity(opacity: settings.opacity, child: image);
        }
        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: left,
              top: top,
              width: imageWidth,
              child: image,
            ),
          ],
        );
      },
    );
  }

  Widget _buildImageWidget(Uint8List bytes, String mime) {
    if (mime == 'image/svg+xml') {
      return SvgPicture.memory(
        bytes,
        fit: BoxFit.contain,
        key: const Key('photo_slideshow_overlay_svg'),
      );
    }
    return Image.memory(
      bytes,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      key: const Key('photo_slideshow_overlay_raster'),
    );
  }
}
