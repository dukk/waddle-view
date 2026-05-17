import 'package:waddle_shared/net/http_debug_uri.dart';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;

import 'package:waddle_shared/blob/blob_store.dart';
import 'package:waddle_shared/config/provider_runtime_config.dart';
import 'package:waddle_shared/curation/reject_filter_context.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/collect/collect_diagnostics.dart';
import 'package:waddle_shared/collect/data_provider.dart';
import 'package:waddle_shared/collect/data_write_context.dart';
import 'package:waddle_shared/integrations/integration_collect.dart';
import 'package:waddle_shared/persistence/tables.dart';
import 'pexels_provider_extra_config.dart';
import 'pexels_video_mp4_pick.dart';

const String kVideoPexelsIntegrationType = 'video_pexels';

const String kDefaultPexelsBaseUrl = 'https://api.pexels.com';

const Duration _rollingHour = Duration(hours: 1);

const Duration _fetchBatchRetention = Duration(hours: 48);

class PexelsVideosDataProvider implements IDataProvider {
  PexelsVideosDataProvider({http.Client? httpClient, int Function()? nowMs})
    : _http = httpClient ?? http.Client(),
      _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  final http.Client _http;
  final int Function() _nowMs;

  @override
  String get id => kVideoPexelsIntegrationType;

  @override
  Future<void> collect(DataWriteContext ctx) async {
    final rows = await enabledIntegrationsForType(ctx.db, id);
    for (final setting in rows) {
      await _collectIntegration(ctx, setting);
    }
  }

  Future<void> _collectIntegration(
    DataWriteContext ctx,
    Integration setting,
  ) async {
    final integrationId = setting.id;
    final nowMs = _nowMs();
    final lastCollectKey = integrationLastCollectKvKey(integrationId);

    if (setting.pollSeconds > 0) {
      final lastRow =
          await (ctx.db.select(ctx.db.configKeyValues)
                ..where((t) => t.key.equals(lastCollectKey)))
              .getSingleOrNull();
      final last = int.tryParse(lastRow?.value ?? '') ?? 0;
      if (nowMs - last < setting.pollSeconds * 1000) {
        ctx.diagnostics.provider(
          'pexels_video: skip poll ($integrationId ${setting.pollSeconds}s gate, lastMs=$last)',
        );
        return;
      }
    }

    late final ProviderRuntimeConfig config;
    try {
      config = await ctx.resolveConfig(integrationId);
    } on Object catch (e, st) {
      ctx.diagnostics.providerFail('pexels_video: resolveConfig', e, st);
      return;
    }

    final token = config.accessToken;
    if (token == null || token.isEmpty) {
      ctx.diagnostics.provider('pexels_video: skip (no API key) id=$integrationId');
      return;
    }

    final extra = PexelsVideoProviderExtraConfig.parse(config.configJson);
    final base = _normalizeBaseUrl(config.baseUrl);
    ctx.diagnostics.provider(
      'pexels_video: collect id=$integrationId base=${safeHttpUriForLog(Uri.parse(base))} '
      'videoBudget/h=${extra.videosPerHour}',
    );

    try {
      await _pruneVideos(ctx, extra.maxVideos);
      await _pruneOldFetchBatches(ctx.db, nowMs);

      final sinceHour = nowMs - _rollingHour.inMilliseconds;
      final videoUsed = await _sumFetchesSince(ctx.db, sinceHour, 'video');
      var videoBudget = extra.videosPerHour - videoUsed;
      if (videoBudget < 0) {
        videoBudget = 0;
      }

      final rejectCtx = await RejectFilterContext.loadFromDb(ctx.db);

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
          key: lastCollectKey,
          value: '$nowMs',
        ),
      );
      ctx.diagnostics.provider(
        'pexels_video: collect finished id=$integrationId (last_collect_ms updated)',
      );
    } on Object catch (e, st) {
      ctx.diagnostics.providerFail('pexels_video: collect', e, st);
    }
  }

  String _normalizeBaseUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return kDefaultPexelsBaseUrl;
    }
    return raw.trim().replaceAll(RegExp(r'/$'), '');
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
    String token, {
    required CollectDiagnostics diagnostics,
  }) async {
    try {
      diagnostics.provider('pexels: GET ${safeHttpUriForLog(uri)}');
      final res = await _http.get(
        uri,
        headers: {'Authorization': token},
      );
      if (res.statusCode != 200) {
        diagnostics.provider(
          'pexels: JSON ${safeHttpUriForLog(uri)} status=${res.statusCode}',
        );
        return null;
      }
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) {
        diagnostics.provider(
          'pexels: JSON ok ${safeHttpUriForLog(uri)} bodyLen=${res.body.length}',
        );
        return decoded;
      }
    } on Object catch (e, st) {
      diagnostics.providerFail('pexels: GET ${uri.path}', e, st);
    }
    return null;
  }

  Future<List<int>?> _downloadBytes(
    Uri uri, {
    required CollectDiagnostics diagnostics,
  }) async {
    try {
      diagnostics.provider('pexels: GET binary ${safeHttpUriForLog(uri)}');
      final res = await _http.get(uri);
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
        diagnostics.provider(
          'pexels: binary status=${res.statusCode} bytes=${res.bodyBytes.length}',
        );
        return null;
      }
      diagnostics.provider('pexels: binary ok bytes=${res.bodyBytes.length}');
      return res.bodyBytes;
    } on Object catch (e, st) {
      diagnostics.providerFail('pexels: binary ${uri.path}', e, st);
      return null;
    }
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

  Future<bool> _tryInsertVideo(
    DataWriteContext ctx, {
    required Map<String, dynamic> video,
    required String category,
    required PexelsVideoProviderExtraConfig extra,
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

    final url = pickPexelsVideoMp4Url(
      video,
      maxWidth: resolvePexelsMaxVideoDownloadWidth(extra.maxVideoDownloadWidth),
    );
    if (url == null || url.isEmpty) {
      return false;
    }

    final bytes = await _downloadBytes(
      Uri.parse(url),
      diagnostics: ctx.diagnostics,
    );
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
        dataProvider: const Value(kMediaDataProviderVideoPexels),
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
    ctx.diagnostics.provider(
      'pexels: stored video id=$id category=$category bytes=${bytes.length}'
      ' dur=${dur}s${blocked ? ' (suppressed by reject list)' : ''}',
    );
    return true;
  }

  Future<int> _collectPopularVideos(
    DataWriteContext ctx, {
    required String base,
    required String token,
    required PexelsVideoProviderExtraConfig extra,
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
      final map = await _getJson(uri, token, diagnostics: ctx.diagnostics);
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
    required PexelsVideoProviderExtraConfig extra,
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
        final map = await _getJson(uri, token, diagnostics: ctx.diagnostics);
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
