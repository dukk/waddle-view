import 'dart:io';

/// Picks a Pexels `video_files` MP4 URL capped for signage decode bandwidth.
///
/// Largest MP4 width not above [maxWidth]; if none qualify, the smallest file.
String? pickPexelsVideoMp4Url(
  Map<String, dynamic> video, {
  required int maxWidth,
}) {
  final files = video['video_files'];
  if (files is! List<dynamic>) {
    return null;
  }
  final cap = maxWidth < 1 ? kPexelsDefaultMaxVideoDownloadWidth : maxWidth;
  String? bestUnderCapLink;
  var bestUnderCapW = -1;
  String? smallestLink;
  var smallestW = 1 << 30;

  for (final f in files) {
    if (f is! Map) {
      continue;
    }
    final m = Map<String, dynamic>.from(f);
    final link = m['link'] as String?;
    final type = m['file_type'] as String? ?? '';
    if (link == null || !type.toLowerCase().contains('mp4')) {
      continue;
    }
    final w = m['width'];
    final width = w is int ? w : w is num ? w.toInt() : 0;
    if (width <= 0) {
      continue;
    }
    if (width <= cap && width > bestUnderCapW) {
      bestUnderCapW = width;
      bestUnderCapLink = link;
    }
    if (width < smallestW) {
      smallestW = width;
      smallestLink = link;
    }
  }
  return bestUnderCapLink ?? smallestLink;
}

/// Default ingest cap (1080p width) when provider config omits `maxVideoDownloadWidth`.
const int kPexelsDefaultMaxVideoDownloadWidth = 1920;

/// Env override for max MP4 width on the display/collect process.
const String kPexelsMaxVideoDownloadWidthEnv =
    'WADDLE_DISPLAY_PEXELS_MAX_VIDEO_DOWNLOAD_WIDTH';

/// Provider `maxVideoDownloadWidth` with optional [kPexelsMaxVideoDownloadWidthEnv].
int resolvePexelsMaxVideoDownloadWidth(int configMaxWidth) {
  final fromEnv = Platform.environment[kPexelsMaxVideoDownloadWidthEnv]?.trim();
  if (fromEnv != null && fromEnv.isNotEmpty) {
    final parsed = int.tryParse(fromEnv);
    if (parsed != null && parsed > 0) {
      return parsed;
    }
  }
  if (configMaxWidth < 1) {
    return kPexelsDefaultMaxVideoDownloadWidth;
  }
  return configMaxWidth;
}
