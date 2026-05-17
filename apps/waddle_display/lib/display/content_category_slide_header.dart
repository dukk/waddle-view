import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:waddle_shared/blob/blob_store.dart' show BlobRef, BlobStore;
import 'package:waddle_shared/blob/display_blob_read.dart';
import 'package:waddle_shared/persistence/database.dart';
import '../theme/display_theme.dart';
import 'content_category_material_icon.dart';
import 'dashboard_viewport_scope.dart';

/// Top-of-slide label + icon for a dashboard [ContentCategories.id] (or matching
/// joke/trivia category id).
class ContentCategorySlideHeader extends StatelessWidget {
  const ContentCategorySlideHeader({
    super.key,
    required this.db,
    required this.blobs,
    required this.theme,
    required this.categoryId,
  });

  final AppDatabase db;
  final BlobStore blobs;
  final ThemeData theme;
  final String? categoryId;

  @override
  Widget build(BuildContext context) {
    final palette = theme.extension<PaletteTertiaryLayers>();
    final iconColor =
        palette?.iconColor ??
        theme.iconTheme.color ??
        theme.colorScheme.onSurfaceVariant;
    final id = categoryId?.trim();
    if (id == null || id.isEmpty) {
      return const SizedBox.shrink();
    }
    final s = DashboardViewportScope.scaleOf(context);
    return FutureBuilder<_CategoryHeaderData>(
      future: _loadCategoryHeaderData(db, blobs, id),
      builder: (context, snap) {
        if (!snap.hasData) {
          return SizedBox(height: 36 * s);
        }
        final data = snap.data!;
        return Padding(
          padding: EdgeInsets.only(bottom: 8 * s),
          child: Row(
            key: const Key('content_category_slide_header'),
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (data.iconBytes != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(6 * s),
                  child: Image.memory(
                    data.iconBytes!,
                    width: 28 * s,
                    height: 28 * s,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Icon(
                  contentCategoryMaterialIcon(data.materialIconName),
                  size: 28 * s,
                  color: iconColor,
                ),
              SizedBox(width: 10 * s),
              Flexible(
                child: Text(
                  data.label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CategoryHeaderData {
  const _CategoryHeaderData({
    required this.label,
    this.materialIconName,
    this.iconBytes,
  });

  final String label;
  final String? materialIconName;
  final Uint8List? iconBytes;
}

Future<_CategoryHeaderData> _loadCategoryHeaderData(
  AppDatabase db,
  BlobStore blobs,
  String categoryId,
) async {
  final cc = await (db.select(
    db.contentCategories,
  )..where((t) => t.id.equals(categoryId))).getSingleOrNull();
  if (cc != null) {
    Uint8List? bytes;
    final bk = cc.iconBlobKey?.trim();
    if (bk != null && bk.isNotEmpty) {
      final meta = await (db.select(
        db.blobMetadata,
      )..where((t) => t.blobKey.equals(bk))).getSingleOrNull();
      if (meta != null) {
        final read = await readDisplayBlobBytes(
          blobs,
          BlobRef(meta.relativePath),
        );
        bytes = read.bytes;
      }
    }
    return _CategoryHeaderData(
      label: cc.label,
      materialIconName: cc.materialIconName,
      iconBytes: bytes,
    );
  }
  final jokeCat = await (db.select(
    db.interestsJokes,
  )..where((t) => t.id.equals(categoryId))).getSingleOrNull();
  if (jokeCat != null) {
    return _CategoryHeaderData(label: jokeCat.label);
  }
  final triviaCat = await (db.select(
    db.interestsTrivia,
  )..where((t) => t.id.equals(categoryId))).getSingleOrNull();
  if (triviaCat != null) {
    return _CategoryHeaderData(label: triviaCat.label);
  }
  return _CategoryHeaderData(label: categoryId);
}
