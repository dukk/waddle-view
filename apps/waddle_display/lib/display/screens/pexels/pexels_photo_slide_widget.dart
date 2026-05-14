import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:waddle_shared/blob/blob_store.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import '../../../curator/screen_program_curator.dart';
import 'package:waddle_shared/persistence/database.dart';
import '../../dashboard_viewport_scope.dart';
import 'pexels_attribution_overlay.dart';
import 'pexels_slide_media.dart';

/// Full-bleed Pexels still with attribution bar at the bottom.
class PexelsPhotoSlideWidget extends StatefulWidget {
  const PexelsPhotoSlideWidget({
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
  State<PexelsPhotoSlideWidget> createState() => _PexelsPhotoSlideWidgetState();
}

class _PexelsPhotoSlideWidgetState extends State<PexelsPhotoSlideWidget> {
  Photo? _row;
  Uint8List? _bytes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    final row = await loadPexelsPhotoForSlide(
      widget.db,
      widget.spec,
      widget.slide,
    );
    Uint8List? bytes;
    if (row != null) {
      bytes = await loadPhotoBlobBytes(widget.db, widget.blobs, row);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _row = row;
      _bytes = bytes;
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
    if (_row == null || _bytes == null) {
      return Center(
        child: Text(
          'No Pexels photo available',
          style: widget.theme.textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
      );
    }
    final row = _row!;
    final bytes = _bytes!;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.memory(
          bytes,
          fit: BoxFit.contain,
          gaplessPlayback: true,
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
