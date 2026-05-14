import 'package:waddle_shared/persistence/database_stats_repository.dart';

/// One row for the photos-vs-videos grouped bar chart.
class MediaCategoryRow {
  const MediaCategoryRow({
    required this.label,
    required this.photos,
    required this.videos,
  });

  final String label;
  final int photos;
  final int videos;
}

class _MutableMedia {
  _MutableMedia(this.label);

  String label;
  int photos = 0;
  int videos = 0;
}

/// Merges [DatabaseHealthSnapshot.photosByCategory] and [videosByCategory],
/// sorts by combined count descending, and folds tail into **Other** when
/// longer than [limit].
List<MediaCategoryRow> mergePhotosVideosForChart(
  DatabaseHealthSnapshot snap, {
  int limit = 8,
}) {
  final map = <String, _MutableMedia>{};
  for (final e in snap.photosByCategory) {
    map.putIfAbsent(e.categoryId, () => _MutableMedia(e.label)).photos += e.count;
  }
  for (final e in snap.videosByCategory) {
    final m = map.putIfAbsent(e.categoryId, () => _MutableMedia(e.label));
    m.videos += e.count;
    if (m.label == e.categoryId && e.label.isNotEmpty) {
      m.label = e.label;
    }
  }
  final list = map.entries
      .map(
        (e) => MediaCategoryRow(
          label: e.value.label,
          photos: e.value.photos,
          videos: e.value.videos,
        ),
      )
      .toList()
    ..sort((a, b) {
      final sa = a.photos + a.videos;
      final sb = b.photos + b.videos;
      return sb.compareTo(sa);
    });

  if (list.length <= limit) {
    return list;
  }
  final head = list.take(limit - 1).toList();
  var op = 0;
  var ov = 0;
  for (var i = limit - 1; i < list.length; i++) {
    op += list[i].photos;
    ov += list[i].videos;
  }
  head.add(MediaCategoryRow(label: 'Other', photos: op, videos: ov));
  return head;
}

int parseDataHealthRefreshSeconds(Map<String, dynamic> cfg) {
  final v = cfg['refreshIntervalSeconds'];
  if (v is int) {
    return v.clamp(15, 300);
  }
  if (v is num) {
    return v.round().clamp(15, 300);
  }
  return 45;
}

String formatDataHealthTime(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}

String formatDataHealthBytes(int b) {
  if (b < 1024) {
    return '$b B';
  }
  if (b < 1024 * 1024) {
    return '${(b / 1024).toStringAsFixed(1)} KB';
  }
  return '${(b / (1024 * 1024)).toStringAsFixed(2)} MB';
}
