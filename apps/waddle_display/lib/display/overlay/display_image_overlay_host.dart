import 'package:flutter/material.dart';
import 'package:waddle_shared/blob/blob_store.dart';
import 'package:waddle_shared/config/display_image_overlay_kv.dart';
import 'package:waddle_shared/persistence/database.dart';

import 'display_image_overlay.dart';

/// Always-on image layer above [child] (slides + ticker), below celebration FX.
class DisplayImageOverlayHost extends StatelessWidget {
  const DisplayImageOverlayHost({
    super.key,
    required this.dashboardKv,
    required this.blobs,
    required this.db,
    required this.child,
  });

  final Map<String, String> dashboardKv;
  final BlobStore blobs;
  final AppDatabase db;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final settings = DisplayImageOverlaySettings.decodeKvValue(
      dashboardKv[kDisplayImageOverlayKvKey],
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (settings.isRenderable)
          Positioned.fill(
            child: IgnorePointer(
              child: DisplayImageOverlay(
                settings: settings,
                blobs: blobs,
                db: db,
              ),
            ),
          ),
      ],
    );
  }
}
