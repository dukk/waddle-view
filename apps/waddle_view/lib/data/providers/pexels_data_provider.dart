import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;

import '../../blob/blob_store.dart';
import '../../config/provider_runtime_config.dart';
import '../../debug/app_debug_log.dart';
import '../../persistence/database.dart';
import '../data_provider.dart';
import '../data_write_context.dart';
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
        return;
      }
    }

    late final ProviderRuntimeConfig config;
    try {
      config = await ctx.resolveConfig(kPexelsProviderId);
    } on Object catch (e, st) {
      AppDebugLog.engineFail('PexelsDataProvider resolveConfig', e, st);
      return;
    }

    final token = config.accessToken;
    if (token == null || token.isEmpty) {
      AppDebugLog.engine(
        'PexelsDataProvider: skip collect (no API key for $kPexelsProviderId)',
      );
      return;
    }

    final extra = PexelsProviderExtraConfig.parse(config.configJson);
    final base = _normalizeBaseUrl(config.baseUrl);

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

      if (photoBudget > 0) {
        if (extra.sources.isEmpty) {
          photoBudget = await _collectCuratedPhotos(
            ctx,
            base: base,
            token: token,
            nowMs: nowMs,
            budget: photoBudget,
          );
        } else {
          for (final s in extra.sources) {
            if (photoBudget <= 0) {
              break;
            }
            photoBudget = await _collectSearchPhotos(
              ctx,
              base: base,
              token: token,
              source: s,
              nowMs: nowMs,
              budget: photoBudget,
            );
          }
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
          );
        } else {
          for (final s in extra.sources) {
            if (videoBudget <= 0) {
              break;
            }
            videoBudget = await _collectSearchVideos(
              ctx,
              base: base,
              token: token,
              extra: extra,
              source: s,
              nowMs: nowMs,
              budget: videoBudget,
            );
          }
        }
      }

      await ctx.db.into(ctx.db.configKeyValues).insertOnConflictUpdate(
        ConfigKeyValuesCompanion.insert(
          key: kPexelsLastCollectKvKey,
          value: '$nowMs',
        ),
      );
    } on Object catch (e, st) {
      AppDebugLog.engineFail('PexelsDataProvider collect', e, st);
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
      final res = await _http.get(
        uri,
        headers: {'Authorization': token},
      );
      if (res.statusCode != 200) {
        AppDebugLog.engine(
          'PexelsDataProvider: ${uri.path} status ${res.statusCode}',
        );
        return null;
      }
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } on Object catch (e, st) {
      AppDebugLog.engineFail('PexelsDataProvider GET ${uri.path}', e, st);
    }
    return null;
  }

  Future<List<int>?> _downloadBytes(Uri uri) async {
    try {
      final res = await _http.get(uri);
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
        return null;
      }
      return res.bodyBytes;
    } on Object catch (e, st) {
      AppDebugLog.engineFail('PexelsDataProvider binary ${uri.path}', e, st);
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

    await ctx.db.into(ctx.db.blobMetadata).insertOnConflictUpdate(
      BlobMetadataCompanion.insert(
        blobKey: logicalKey,
        sha256: ref.storageKey.split('/').last,
        relativePath: ref.storageKey,
        bytes: bytes.length,
        mimeType: Value(mime),
        capturedAt: DateTime.fromMillisecondsSinceEpoch(nowMs),
      ),
    );

    await ctx.db.into(ctx.db.photos).insert(
      PhotosCompanion.insert(
        id: id,
        category: Value(category),
        dataProvider: Value(kPexelsProviderId),
        mediaBlobKey: logicalKey,
        photographerName: '${photo['photographer'] ?? ''}',
        photographerUrl: '${photo['photographer_url'] ?? ''}',
        pexelsPageUrl: '${photo['url'] ?? ''}',
        altText: Value('${photo['alt'] ?? ''}'),
        fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(nowMs),
      ),
    );
    return true;
  }

  Future<bool> _tryInsertVideo(
    DataWriteContext ctx, {
    required Map<String, dynamic> video,
    required String category,
    required PexelsProviderExtraConfig extra,
    required int nowMs,
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

    await ctx.db.into(ctx.db.videos).insert(
      VideosCompanion.insert(
        id: id,
        category: Value(category),
        dataProvider: Value(kPexelsProviderId),
        mediaBlobKey: logicalKey,
        photographerName: photographerName,
        photographerUrl: photographerUrl,
        pexelsPageUrl: '${video['url'] ?? ''}',
        altText: Value(''),
        durationSeconds: dur,
        fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(nowMs),
      ),
    );
    return true;
  }

  Future<int> _collectCuratedPhotos(
    DataWriteContext ctx, {
    required String base,
    required String token,
    required int nowMs,
    required int budget,
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

  Future<int> _collectSearchPhotos(
    DataWriteContext ctx, {
    required String base,
    required String token,
    required PexelsSourceSpec source,
    required int nowMs,
    required int budget,
  }) async {
    var left = budget;
    var page = 1;
    while (left > 0 && page <= 15) {
      final uri = Uri.parse(
        '$base/v1/search?query=${Uri.encodeComponent(source.query)}'
        '&per_page=15&page=$page',
      );
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
          category: source.category,
          nowMs: nowMs,
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

  Future<int> _collectPopularVideos(
    DataWriteContext ctx, {
    required String base,
    required String token,
    required PexelsProviderExtraConfig extra,
    required int nowMs,
    required int budget,
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

  Future<int> _collectSearchVideos(
    DataWriteContext ctx, {
    required String base,
    required String token,
    required PexelsProviderExtraConfig extra,
    required PexelsSourceSpec source,
    required int nowMs,
    required int budget,
  }) async {
    var left = budget;
    var page = 1;
    while (left > 0 && page <= 15) {
      final uri = Uri.parse(
        '$base/v1/videos/search?query=${Uri.encodeComponent(source.query)}'
        '&per_page=15&page=$page',
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
          category: source.category,
          extra: extra,
          nowMs: nowMs,
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
}
