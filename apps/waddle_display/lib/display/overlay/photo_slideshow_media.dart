import 'package:drift/drift.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/display_overlay_photo_slideshow_settings.dart';

/// Builds SQL `WHERE` fragments and variables for slideshow photo selection.
class _SlideshowPhotoQuery {
  _SlideshowPhotoQuery(this.settings, {this.excludePhotoId});

  final PhotoSlideshowOverlaySettings settings;
  final String? excludePhotoId;

  final clauses = <String>['p.suppressed = 0'];
  final variables = <Variable<Object>>[];

  void build() {
    if (settings.categoryIds.isNotEmpty) {
      clauses.add(
        'p.category IN (${List.filled(settings.categoryIds.length, '?').join(',')})',
      );
      for (final id in settings.categoryIds) {
        variables.add(Variable<String>(id));
      }
    }
    if (settings.minWidth != null) {
      clauses.add('m.pixel_width >= ?');
      variables.add(Variable<int>(settings.minWidth!));
    }
    if (settings.maxWidth != null) {
      clauses.add('m.pixel_width <= ?');
      variables.add(Variable<int>(settings.maxWidth!));
    }
    if (settings.minHeight != null) {
      clauses.add('m.pixel_height >= ?');
      variables.add(Variable<int>(settings.minHeight!));
    }
    if (settings.maxHeight != null) {
      clauses.add('m.pixel_height <= ?');
      variables.add(Variable<int>(settings.maxHeight!));
    }
    if (settings.hasDimensionOrAspectFilter) {
      clauses.add('m.pixel_width IS NOT NULL AND m.pixel_height IS NOT NULL');
    }
    switch (settings.aspectRatio) {
      case kPhotoSlideshowAspectLandscape:
        clauses.add('m.pixel_width > m.pixel_height * 1.05');
        if (!settings.hasDimensionOrAspectFilter) {
          clauses.add('m.pixel_width IS NOT NULL AND m.pixel_height IS NOT NULL');
        }
      case kPhotoSlideshowAspectPortrait:
        clauses.add('m.pixel_height > m.pixel_width * 1.05');
        if (!settings.hasDimensionOrAspectFilter) {
          clauses.add('m.pixel_width IS NOT NULL AND m.pixel_height IS NOT NULL');
        }
      case kPhotoSlideshowAspectSquare:
        clauses.add(
          'CAST(m.pixel_width AS REAL) / m.pixel_height BETWEEN 0.95 AND 1.05',
        );
        if (!settings.hasDimensionOrAspectFilter) {
          clauses.add('m.pixel_width IS NOT NULL AND m.pixel_height IS NOT NULL');
        }
      case kPhotoSlideshowAspectWidescreen:
        clauses.add(
          'CAST(m.pixel_width AS REAL) / m.pixel_height BETWEEN 1.6 AND 1.9',
        );
        if (!settings.hasDimensionOrAspectFilter) {
          clauses.add('m.pixel_width IS NOT NULL AND m.pixel_height IS NOT NULL');
        }
      case kPhotoSlideshowAspectStandard43:
        clauses.add(
          'CAST(m.pixel_width AS REAL) / m.pixel_height BETWEEN 1.25 AND 1.4',
        );
        if (!settings.hasDimensionOrAspectFilter) {
          clauses.add('m.pixel_width IS NOT NULL AND m.pixel_height IS NOT NULL');
        }
      case kPhotoSlideshowAspectAny:
        break;
    }
    final exclude = excludePhotoId?.trim();
    if (exclude != null && exclude.isNotEmpty) {
      clauses.add('p.id != ?');
      variables.add(Variable<String>(exclude));
    }
  }

  String get whereSql => clauses.join(' AND ');
}

String _slideshowFromSql() =>
    'FROM photos p INNER JOIN blob_metadata m ON m.blob_key = p.media_blob_key';

/// Counts non-suppressed photos matching [settings] (for skip-repick logic).
Future<int> countPhotosForSlideshow(
  AppDatabase db,
  PhotoSlideshowOverlaySettings settings,
) async {
  final q = _SlideshowPhotoQuery(settings)..build();
  final row = await db
      .customSelect(
        'SELECT COUNT(*) AS c ${_slideshowFromSql()} WHERE ${q.whereSql}',
        variables: q.variables,
      )
      .getSingle();
  return row.read<int>('c');
}

/// Picks one random photo matching [settings], optionally excluding [excludePhotoId].
Future<Photo?> selectRandomPhotoForSlideshow(
  AppDatabase db,
  PhotoSlideshowOverlaySettings settings, {
  String? excludePhotoId,
}) async {
  final q = _SlideshowPhotoQuery(settings, excludePhotoId: excludePhotoId)
    ..build();
  final row = await db
      .customSelect(
        'SELECT p.id AS photo_id ${_slideshowFromSql()} WHERE ${q.whereSql} '
        'ORDER BY random() LIMIT 1',
        variables: q.variables,
      )
      .getSingleOrNull();
  if (row == null) {
    return null;
  }
  final id = row.read<String>('photo_id');
  return (db.select(db.photos)..where((t) => t.id.equals(id))).getSingleOrNull();
}
