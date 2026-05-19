import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:waddle_shared/blob/blob_store.dart';
import 'package:waddle_shared/blob/display_blob_read.dart';
import 'package:waddle_shared/config/display_image_overlay_kv.dart';
import 'package:waddle_shared/persistence/database.dart';

/// Renders a single always-on image at a configured viewport position.
class DisplayImageOverlay extends StatefulWidget {
  const DisplayImageOverlay({
    super.key,
    required this.settings,
    required this.blobs,
    required this.db,
  });

  final DisplayImageOverlaySettings settings;
  final BlobStore blobs;
  final AppDatabase db;

  @override
  State<DisplayImageOverlay> createState() => _DisplayImageOverlayState();
}

class _DisplayImageOverlayState extends State<DisplayImageOverlay> {
  Uint8List? _bytes;
  String _mimeType = '';

  @override
  void initState() {
    super.initState();
    unawaited(_loadImage());
  }

  @override
  void didUpdateWidget(covariant DisplayImageOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings.imageBlobKey != widget.settings.imageBlobKey) {
      unawaited(_loadImage());
    }
  }

  Future<void> _loadImage() async {
    if (!widget.settings.isRenderable) {
      if (mounted) {
        setState(() {
          _bytes = null;
          _mimeType = '';
        });
      }
      return;
    }
    final blobKey = widget.settings.imageBlobKey;
    final row = await (widget.db.select(widget.db.blobMetadata)
          ..where((t) => t.blobKey.equals(blobKey)))
        .getSingleOrNull();
    if (!mounted) {
      return;
    }
    if (row == null) {
      setState(() {
        _bytes = null;
        _mimeType = '';
      });
      return;
    }
    final read = await readDisplayBlobBytes(
      widget.blobs,
      BlobRef(row.relativePath),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      if (read.isOk) {
        _bytes = read.bytes;
        _mimeType = row.mimeType ?? '';
      } else {
        _bytes = null;
        _mimeType = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.settings.isRenderable || _bytes == null) {
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
        key: const Key('display_image_overlay_svg'),
      );
    }
    return Image.memory(
      bytes,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      key: const Key('display_image_overlay_raster'),
    );
  }
}
