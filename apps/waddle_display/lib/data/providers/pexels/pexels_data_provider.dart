import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;

import '../../../blob/blob_store.dart';
import 'package:waddle_shared/config/provider_runtime_config.dart';
import 'package:waddle_shared/curation/reject_filter_context.dart';
import '../../../debug/app_debug_log.dart';
import 'package:waddle_shared/persistence/database.dart';
import '../../data_provider.dart';
import '../../data_write_context.dart';
import 'pexels_provider_extra_config.dart';

const String kPexelsProviderId = 'pexels';

/// Last successful [PexelsDataProvider.collect] completion (for [ProviderSettings.pollSeconds]).
const String kPexelsLastCollectKvKey = 'provider.pexels.last_collect_ms';

const String kDefaultPexelsBaseUrl = 'https://api.pexels.com';

const Duration _rollingHour = Duration(hours: 1);

const Duration _fetchBatchRetention = Duration(hours: 48);

class PexelsDataProvider implements IDataProvider {
  PexelsDataProvider({http.Client? httpClient, int Function()? nowMs})
    : _http = httpClient ?? http.Client(),
      _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  final http.Client _http;
  final int Function() _nowMs;

  @override
  String get id => kPexelsProviderId;

  @override
  Future<void> collect(DataWriteContext ctx) async {
    final setting =
        await (ctx.db.select(
              ctx.db.providerSettings,
            )..where((t) => t.id.equals(kPexelsProviderId)))
            .getSingleOrNull();
    if (setting == null || !setting.enabled) {
      AppDebugLog.provider('pexels: skip (disabled)');
      return;
    }

    final nowMs = _nowMs();

    if (setting.pollSeconds > 0) {
      final lastRow =
          await (ctx.db.select(
                ctx.db.configKeyValues,
              )..where((t) => t.key.equals(kPexelsLastCollectKvKey)))
              .getSingleOrNull();
      final last = int.tryParse(lastRow?.value ?? '') ?? 0;
      if (nowMs - last < setting.pollSeconds * 1000) {
        AppDebugLog.provider(
          'pexels: skip poll (${setting.pollSeconds}s gate, lastMs=$last)',
        );
        return;
      }
    }

    late final ProviderRuntimeConfig config;
    try {
      config = await ctx.resolveConfig(kPexelsProviderId);
    } on Object catch (e, st) {
      AppDebugLog.providerFail('pexels: resolveConfig', e, st);
      return;
    }

    final token = config.accessToken;
    if (token == null || token.isEmpty) {
      AppDebugLog.provider('pexels: skip (no API key)');
      return;
    }

    final extra = PexelsProviderExtraConfig.parse(config.configJson);
    final base = _normalizeBaseUrl(config.baseUrl);
    AppDebugLog.provider(
      'pexels: collect base=${AppDebugLog.safeHttpUri(Uri.parse(base))} '
      'photoBudget/h=${extra.photosPerHour} videoBudget/h=${extra.videosPerHour}',
    );

    try {
      await _prunePhotos(ctx, extra.maxPhotos);
      await _pruneVideos(ctx, extra.maxVideos);
      await _pruneOldFetchBatches(ctx.db, nowMs);

      final sinceHour = nowMs - _rollingHour.inMilliseconds;
      final photoUsed = await _sumFetchesSince(ctx.db, sinceHour, 'photo');
      final videoUsed = await _sumFetchesSince(ctx.db, sinceHour, 'video');
      var photoBudget = extra.photosPerHour - photoUsed;
      var videoBudget = extra.videosPerHour - videoUsed;
      if (photoBudget < 0) {
        photoBudget = 0;
      }
      if (videoBudget < 0) {
        videoBudget = 0;
      }

      final rejectCtx = await RejectFilterContext.loadFromDb(ctx.db);

      if (photoBudget > 0) {
        if (extra.sources.isEmpty) {
          photoBudget = await _collectCuratedPhotos(
            ctx,
            base: base,
            token: token,
            nowMs: nowMs,
            budget: photoBudget,
            rejectCtx: rejectCtx,
          );
        } else {
          photoBudget = await _collectSearchPhotosRoundRobin(
            ctx,
            base: base,
            token: token,
            sources: extra.sources,
            nowMs: nowMs,
            budget: photoBudget,
            rejectCtx: rejectCtx,
          );
        }
      }

      if (videoBudget > 0) {
        if (extra.sources.isEmpty) {
          videoBudget = await _collectPopularVideos(
            ctx,
            base: base,
            token: token,
            extra: extra,
            nowMs: nowMs,
            budget: videoBudget,
            rejectCtx: rejectCtx,
          );
        } else {
          videoBudget = await _collectSearchVideosRoundRobin(
            ctx,
            base: base,
            token: token,
            extra: extra,
            sources: extra.sources,
            nowMs: nowMs,
            budget: videoBudget,
            rejectCtx: rejectCtx,
          );
        }
      }

      await ctx.db.into(ctx.db.configKeyValues).insertOnConflictUpdate(
        ConfigKeyValuesCompanion.insert(
          key: kPexelsLastCollectKvKey,
          value: '$nowMs',
        ),
      );
      AppDebugLog.provider('pexels: collect finished (last_collect_ms updated)');
    } on Object catch (e, st) {
      AppDebugLog.providerFail('pexels: collect', e, st);
    }
  }

  String _normalizeBaseUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return kDefaultPexelsBaseUrl;
    }
    return raw.trim().replaceAll(RegExp(r'/$'), '');
  }

  Future<void> _prunePhotos(DataWriteContext ctx, int max) async {
    if (max < 1) {
      return;
    }
    final rows =
        await (ctx.db.select(
              ctx.db.photos,
            )..orderBy([(t) => OrderingTerm.asc(t.fetchedAtMs)]))
            .get();
    if (rows.length <= max) {
      return;
    }
    final removeCount = rows.length - max;
    for (var i = 0; i < removeCount; i++) {
      await _deletePexelsPhoto(ctx, rows[i]);
    }
  }

  Future<void> _pruneVideos(DataWriteContext ctx, int max) async {
    if (max < 1) {
      return;
    }
    final rows =
        await (ctx.db.select(
              ctx.db.videos,
            )..orderBy([(t) => OrderingTerm.asc(t.fetchedAtMs)]))
            .get();
    if (rows.length <= max) {
      return;
    }
    final removeCount = rows.length - max;
    for (var i = 0; i < removeCount; i++) {
      await _deletePexelsVideo(ctx, rows[i]);
    }
  }

  Future<void> _deletePexelsPhoto(DataWriteContext ctx, Photo row) async {
    final key = row.mediaBlobKey;
    final meta =
        await (ctx.db.select(
              ctx.db.blobMetadata,
            )..where((t) => t.blobKey.equals(key)))
            .getSingleOrNull();
    if (meta != null) {
      await ctx.blobs.delete(BlobRef(meta.relativePath));
      await (ctx.db.delete(
            ctx.db.blobMetadata,
          )..where((t) => t.blobKey.equals(key)))
          .go();
    }
    await (ctx.db.delete(
          ctx.db.photos,
        )..where((t) => t.id.equals(row.id)))
        .go();
  }

  Future<void> _deletePexelsVideo(DataWriteContext ctx, Video row) async {
    final key = row.mediaBlobKey;
    final meta =
        await (ctx.db.select(
              ctx.db.blobMetadata,
            )..where((t) => t.blobKey.equals(key)))
            .getSingleOrNull();
    if (meta != null) {
      await ctx.blobs.delete(BlobRef(meta.relativePath));
      await (ctx.db.delete(
            ctx.db.blobMetadata,
          )..where((t) => t.blobKey.equals(key)))
          .go();
    }
    await (ctx.db.delete(
          ctx.db.videos,
        )..where((t) => t.id.equals(row.id)))
        .go();
  }

  Future<void> _pruneOldFetchBatches(AppDatabase db, int nowMs) async {
    final cutoffMs = nowMs - _fetchBatchRetention.inMilliseconds;
    final cutoff = DateTime.fromMillisecondsSinceEpoch(cutoffMs);
    await (db.delete(
          db.pexelsFetchBatches,
        )..where((t) => t.requestedAtMs.isSmallerThanValue(cutoff)))
        .go();
  }

  Future<int> _sumFetchesSince(
    AppDatabase db,
    int sinceMsInclusive,
    String kind,
  ) async {
    final since = DateTime.fromMillisecondsSinceEpoch(sinceMsInclusive);
    final rows =
        await (db.select(
              db.pexelsFetchBatches,
            )..where(
                (t) =>
                    t.kind.equals(kind) &
                    t.requestedAtMs.isBiggerOrEqualValue(since),
              ))
            .get();
    var sum = 0;
    for (final r in rows) {
      sum += r.count;
    }
    return sum;
  }

  Future<void> _recordFetch(AppDatabase db, int nowMs, String kind) async {
    await db.into(db.pexelsFetchBatches).insert(
      PexelsFetchBatchesCompanion.insert(
        requestedAtMs: DateTime.fromMillisecondsSinceEpoch(nowMs),
        kind: kind,
        count: const Value(1),
      ),
    );
  }

  Future<Map<String, dynamic>?> _getJson(
    Uri uri,
    String token,
  ) async {
    try {
      AppDebugLog.provider('pexels: GET ${AppDebugLog.safeHttpUri(uri)}');
      final res = await _http.get(
        uri,
        headers: {'Authorization': token},
      );
      if (res.statusCode != 200) {
        AppDebugLog.provider(
          'pexels: JSON ${AppDebugLog.safeHttpUri(uri)} status=${res.statusCode}',
        );
        return null;
      }
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) {
        AppDebugLog.provider(
          'pexels: JSON ok ${AppDebugLog.safeHttpUri(uri)} bodyLen=${res.body.length}',
        );
        return decoded;
      }
    } on Object catch (e, st) {
      AppDebugLog.providerFail('pexels: GET ${uri.path}', e, st);
    }
    return null;
  }

  Future<List<int>?> _downloadBytes(Uri uri) async {
    try {
      AppDebugLog.provider('pexels: GET binary ${AppDebugLog.safeHttpUri(uri)}');
      final res = await _http.get(uri);
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
        AppDebugLog.provider(
          'pexels: binary status=${res.statusCode} bytes=${res.bodyBytes.length}',
        );
        return null;
      }
      AppDebugLog.provider('pexels: binary ok bytes=${res.bodyBytes.length}');
      return res.bodyBytes;
    } on Object catch (e, st) {
      AppDebugLog.providerFail('pexels: binary ${uri.path}', e, st);
      return null;
    }
  }

  String? _pickPhotoUrl(Map<String, dynamic> photo) {
    final src = photo['src'];
    if (src is! Map) {
      return null;
    }
    final large = src['large'];
    if (large is String && large.isNotEmpty) {
      return large;
    }
    final original = src['original'];
    if (original is String && original.isNotEmpty) {
      return original;
    }
    return null;
  }

  String? _pickVideoMp4Url(Map<String, dynamic> video) {
    final files = video['video_files'];
    if (files is! List<dynamic>) {
      return null;
    }
    var bestW = -1;
    String? bestLink;
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
      if (width > bestW) {
        bestW = width;
        bestLink = link;
      }
    }
    return bestLink;
  }

  String? _pexelsIdString(Object? raw) {
    if (raw is int) {
      return '$raw';
    }
    if (raw is String && raw.isNotEmpty) {
      return raw;
    }
    return null;
  }

  int? _positivePixelDimension(Object? raw) {
    if (raw is int) {
      return raw > 0 ? raw : null;
    }
    if (raw is num) {
      final i = raw.toInt();
      return i > 0 ? i : null;
    }
    return null;
  }

  int _videoDurationSeconds(Map<String, dynamic> video) {
    final d = video['duration'];
    if (d is int) {
      return d;
    }
    if (d is num) {
      return d.toInt();
    }
    return 0;
  }

  Future<bool> _tryInsertPhoto(
    DataWriteContext ctx, {
    required Map<String, dynamic> photo,
    required String category,
    required int nowMs,
    required RejectFilterContext rejectCtx,
  }) async {
    final id = _pexelsIdString(photo['id']);
    if (id == null) {
      return false;
    }

    final exists =
        await (ctx.db.select(
              ctx.db.photos,
            )..where((t) => t.id.equals(id)))
            .getSingleOrNull();
    if (exists != null) {
      return false;
    }

    final url = _pickPhotoUrl(photo);
    if (url == null || url.isEmpty) {
      return false;
    }

    final bytes = await _downloadBytes(Uri.parse(url));
    if (bytes == null || bytes.isEmpty) {
      return false;
    }

    final logicalKey = 'pexels/photo/$id/image';
    final ref = await ctx.blobs.putBytes(bytes, logicalKey: logicalKey);
    final mime =
        'image/jpeg'; // Pexels JPEG/PNG; display code tolerates Image.memory
    final pw = _positivePixelDimension(photo['width']);
    final ph = _positivePixelDimension(photo['height']);

    await ctx.db.into(ctx.db.blobMetadata).insertOnConflictUpdate(
      BlobMetadataCompanion.insert(
        blobKey: logicalKey,
        sha256: ref.storageKey.split('/').last,
        relativePath: ref.storageKey,
        bytes: bytes.length,
        mimeType: Value(mime),
        capturedAt: DateTime.fromMillisecondsSinceEpoch(nowMs),
        pixelWidth: pw != null ? Value(pw) : const Value.absent(),
        pixelHeight: ph != null ? Value(ph) : const Value.absent(),
      ),
    );

    final photographerName = '${photo['photographer'] ?? ''}';
    final photographerUrl = '${photo['photographer_url'] ?? ''}';
    final pageUrl = '${photo['url'] ?? ''}';
    final altText = '${photo['alt'] ?? ''}';
    final blocked = rejectCtx.isMediaRejected(
      photographer: photographerName,
      altText: altText,
      urls: [photographerUrl, pageUrl],
    );

    await ctx.db.into(ctx.db.photos).insert(
      PhotosCompanion.insert(
        id: id,
        category: Value(category),
        dataProvider: Value(kPexelsProviderId),
        mediaBlobKey: logicalKey,
        photographerName: photographerName,
        photographerUrl: photographerUrl,
        pexelsPageUrl: pageUrl,
        altText: Value(altText),
        fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(nowMs),
        suppressed: Value(blocked),
      ),
    );
    AppDebugLog.provider(
      'pexels: stored photo id=$id category=$category bytes=${bytes.length}'
      '${blocked ? ' (suppressed by reject list)' : ''}',
    );
    return true;
  }

  Future<bool> _tryInsertVideo(
    DataWriteContext ctx, {
    required Map<String, dynamic> video,
    required String category,
    required PexelsProviderExtraConfig extra,
    required int nowMs,
    required RejectFilterContext rejectCtx,
  }) async {
    final dur = _videoDurationSeconds(video);
    if (dur < extra.minVideoSeconds || dur > extra.maxVideoSeconds) {
      return false;
    }

    final id = _pexelsIdString(video['id']);
    if (id == null) {
      return false;
    }

    final exists =
        await (ctx.db.select(
              ctx.db.videos,
            )..where((t) => t.id.equals(id)))
            .getSingleOrNull();
    if (exists != null) {
      return false;
    }

    final url = _pickVideoMp4Url(video);
    if (url == null || url.isEmpty) {
      return false;
    }

    final bytes = await _downloadBytes(Uri.parse(url));
    if (bytes == null || bytes.isEmpty) {
      return false;
    }

    final logicalKey = 'pexels/video/$id/media';
    final ref = await ctx.blobs.putBytes(bytes, logicalKey: logicalKey);

    await ctx.db.into(ctx.db.blobMetadata).insertOnConflictUpdate(
      BlobMetadataCompanion.insert(
        blobKey: logicalKey,
        sha256: ref.storageKey.split('/').last,
        relativePath: ref.storageKey,
        bytes: bytes.length,
        mimeType: const Value('video/mp4'),
        capturedAt: DateTime.fromMillisecondsSinceEpoch(nowMs),
      ),
    );

    final userRaw = video['user'];
    var photographerName = '';
    var photographerUrl = '';
    if (userRaw is Map) {
      final u = Map<String, dynamic>.from(userRaw);
      photographerName = '${u['name'] ?? ''}';
      photographerUrl = '${u['url'] ?? ''}';
    }

    final pageUrl = '${video['url'] ?? ''}';
    final blocked = rejectCtx.isMediaRejected(
      photographer: photographerName,
      altText: '',
      urls: [photographerUrl, pageUrl],
    );

    await ctx.db.into(ctx.db.videos).insert(
      VideosCompanion.insert(
        id: id,
        category: Value(category),
        dataProvider: Value(kPexelsProviderId),
        mediaBlobKey: logicalKey,
        photographerName: photographerName,
        photographerUrl: photographerUrl,
        pexelsPageUrl: pageUrl,
        altText: const Value(''),
        durationSeconds: dur,
        fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(nowMs),
        suppressed: Value(blocked),
      ),
    );
    AppDebugLog.provider(
      'pexels: stored video id=$id category=$category bytes=${bytes.length}'
      ' dur=${dur}s${blocked ? ' (suppressed by reject list)' : ''}',
    );
    return true;
  }

  Future<int> _collectCuratedPhotos(
    DataWriteContext ctx, {
    required String base,
    required String token,
    required int nowMs,
    required int budget,
    required RejectFilterContext rejectCtx,
  }) async {
    var left = budget;
    var page = 1;
    while (left > 0 && page <= 20) {
      final uri = Uri.parse('$base/v1/curated?page=$page&per_page=15');
      final map = await _getJson(uri, token);
      if (map == null) {
        break;
      }
      final photos = map['photos'] as List<dynamic>?;
      if (photos == null || photos.isEmpty) {
        break;
      }
      for (final raw in photos) {
        if (left <= 0) {
          break;
        }
        if (raw is! Map) {
          continue;
        }
        final photo = Map<String, dynamic>.from(raw);
        final inserted = await _tryInsertPhoto(
          ctx,
          photo: photo,
          category: 'pexels',
          nowMs: nowMs,
          rejectCtx: rejectCtx,
        );
        if (inserted) {
          left--;
          await _recordFetch(ctx.db, nowMs, 'photo');
        }
      }
      if (map['next_page'] == null) {
        break;
      }
      page++;
    }
    return left;
  }

  Future<int> _collectSearchPhotosRoundRobin(
    DataWriteContext ctx, {
    required String base,
    required String token,
    required List<PexelsSourceSpec> sources,
    required int nowMs,
    required int budget,
    required RejectFilterContext rejectCtx,
  }) async {
    var left = budget;
    if (left <= 0 || sources.isEmpty) {
      return left;
    }
    final sourcePage = <int>[for (var i = 0; i < sources.length; i++) 1];
    final sourceDone = <bool>[for (var i = 0; i < sources.length; i++) false];
    while (left > 0) {
      var progressed = false;
      for (var i = 0; i < sources.length && left > 0; i++) {
        if (sourceDone[i]) {
          continue;
        }
        final source = sources[i];
        final page = sourcePage[i];
        if (page > 15) {
          sourceDone[i] = true;
          continue;
        }
        final uri = Uri.parse(
          '$base/v1/search?query=${Uri.encodeComponent(source.query)}'
          '&per_page=15&page=$page',
        );
        final map = await _getJson(uri, token);
        sourcePage[i] = page + 1;
        if (map == null) {
          sourceDone[i] = true;
          continue;
        }
        final photos = map['photos'] as List<dynamic>?;
        if (photos == null || photos.isEmpty) {
          sourceDone[i] = true;
          continue;
        }
        if (map['next_page'] == null) {
          sourceDone[i] = true;
        }
        for (final raw in photos) {
          if (left <= 0) {
            break;
          }
          if (raw is! Map) {
            continue;
          }
          final photo = Map<String, dynamic>.from(raw);
          final inserted = await _tryInsertPhoto(
            ctx,
            photo: photo,
            category: source.category,
            nowMs: nowMs,
            rejectCtx: rejectCtx,
          );
          if (inserted) {
            left--;
            progressed = true;
            await _recordFetch(ctx.db, nowMs, 'photo');
            break;
          }
        }
      }
      if (!progressed || sourceDone.every((e) => e)) {
        break;
      }
    }
    return left;
  }

  Future<int> _collectPopularVideos(
    DataWriteContext ctx, {
    required String base,
    required String token,
    required PexelsProviderExtraConfig extra,
    required int nowMs,
    required int budget,
    required RejectFilterContext rejectCtx,
  }) async {
    var left = budget;
    var page = 1;
    while (left > 0 && page <= 20) {
      final uri = Uri.parse(
        '$base/v1/videos/popular?per_page=15&page=$page'
        '&min_duration=${extra.minVideoSeconds}'
        '&max_duration=${extra.maxVideoSeconds}',
      );
      final map = await _getJson(uri, token);
      if (map == null) {
        break;
      }
      final videos = map['videos'] as List<dynamic>?;
      if (videos == null || videos.isEmpty) {
        break;
      }
      for (final raw in videos) {
        if (left <= 0) {
          break;
        }
        if (raw is! Map) {
          continue;
        }
        final video = Map<String, dynamic>.from(raw);
        final inserted = await _tryInsertVideo(
          ctx,
          video: video,
          category: 'pexels',
          extra: extra,
          nowMs: nowMs,
          rejectCtx: rejectCtx,
        );
        if (inserted) {
          left--;
          await _recordFetch(ctx.db, nowMs, 'video');
        }
      }
      if (map['next_page'] == null) {
        break;
      }
      page++;
    }
    return left;
  }

  Future<int> _collectSearchVideosRoundRobin(
    DataWriteContext ctx, {
    required String base,
    required String token,
    required PexelsProviderExtraConfig extra,
    required List<PexelsSourceSpec> sources,
    required int nowMs,
    required int budget,
    required RejectFilterContext rejectCtx,
  }) async {
    var left = budget;
    if (left <= 0 || sources.isEmpty) {
      return left;
    }
    final sourcePage = <int>[for (var i = 0; i < sources.length; i++) 1];
    final sourceDone = <bool>[for (var i = 0; i < sources.length; i++) false];
    while (left > 0) {
      var progressed = false;
      for (var i = 0; i < sources.length && left > 0; i++) {
        if (sourceDone[i]) {
          continue;
        }
        final source = sources[i];
        final page = sourcePage[i];
        if (page > 15) {
          sourceDone[i] = true;
          continue;
        }
        final uri = Uri.parse(
          '$base/v1/videos/search?query=${Uri.encodeComponent(source.query)}'
          '&per_page=15&page=$page',
        );
        final map = await _getJson(uri, token);
        sourcePage[i] = page + 1;
        if (map == null) {
          sourceDone[i] = true;
          continue;
        }
        final videos = map['videos'] as List<dynamic>?;
        if (videos == null || videos.isEmpty) {
          sourceDone[i] = true;
          continue;
        }
        if (map['next_page'] == null) {
          sourceDone[i] = true;
        }
        for (final raw in videos) {
          if (left <= 0) {
            break;
          }
          if (raw is! Map) {
            continue;
          }
          final video = Map<String, dynamic>.from(raw);
          final inserted = await _tryInsertVideo(
            ctx,
            video: video,
            category: source.category,
            extra: extra,
            nowMs: nowMs,
            rejectCtx: rejectCtx,
          );
          if (inserted) {
            left--;
            progressed = true;
            await _recordFetch(ctx.db, nowMs, 'video');
            break;
          }
        }
      }
      if (!progressed || sourceDone.every((e) => e)) {
        break;
      }
    }
    return left;
  }
}
