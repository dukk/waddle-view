import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;

import '../../../blob/blob_store.dart';
import 'package:waddle_shared/config/provider_runtime_config.dart';
import 'package:waddle_shared/curation/reject_filter_context.dart';
import '../../../debug/app_debug_log.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';
import '../../data_provider.dart';
import '../../data_write_context.dart';
import 'bing_image_of_day_extra_config.dart';

const String kBingImageOfDayProviderId = 'bing_iotd';

/// Last successful [BingImageOfDayDataProvider.collect] (for [ProviderSettings.pollSeconds]).
const String kBingImageOfDayLastCollectKvKey = 'provider.bing_iotd.last_collect_ms';

/// Desktop UA (matches TimothyYe/bing-wallpaper `wallpaper.go`).
const String kBingWallpaperUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/131.0.0.0 Safari/537.36 Edg/131.0.0.0';

const Duration _bingHttpTimeout = Duration(seconds: 5);

String normalizeBingBaseUrl(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return 'https://www.bing.com';
  }
  return raw.trim().replaceAll(RegExp(r'/$'), '');
}

/// `{base}{urlbase}_{resolution}.jpg` (see bing-wallpaper `Get`).
String buildBingWallpaperImageUrl(
  String base,
  String urlbase,
  String resolution,
) {
  final b = normalizeBingBaseUrl(base);
  return '$b${urlbase}_$resolution.jpg';
}

String _photographerFromCopyright(String copyright) {
  final re = RegExp(r'\(\s*©\s*([^)]+)\)');
  final m = re.firstMatch(copyright);
  if (m != null) {
    final inner = m.group(1)?.trim();
    if (inner != null && inner.isNotEmpty) {
      return inner;
    }
  }
  final t = copyright.trim();
  return t.isEmpty ? 'Bing' : t;
}

Uri _archiveUri(String base, String mkt) {
  final b = normalizeBingBaseUrl(base);
  return Uri.parse('$b/HPImageArchive.aspx').replace(
    queryParameters: {
      'format': 'js',
      'idx': '0',
      'n': '1',
      'mkt': mkt,
    },
  );
}

class BingImageOfDayDataProvider implements IDataProvider {
  BingImageOfDayDataProvider({
    http.Client? httpClient,
    int Function()? nowMs,
    Duration? requestTimeout,
  }) : _http = httpClient ?? http.Client(),
       _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch),
       _requestTimeout = requestTimeout ?? _bingHttpTimeout;

  final http.Client _http;
  final int Function() _nowMs;
  final Duration _requestTimeout;

  @override
  String get id => kBingImageOfDayProviderId;

  Map<String, String> _bingHeaders(String refererBase) => {
    'Referer': refererBase,
    'User-Agent': kBingWallpaperUserAgent,
  };

  Future<http.Response> _bingGet(Uri uri, String refererBase) async {
    return _http
        .get(uri, headers: _bingHeaders(refererBase))
        .timeout(_requestTimeout);
  }

  @override
  Future<void> collect(DataWriteContext ctx) async {
    final setting =
        await (ctx.db.select(
              ctx.db.providerSettings,
            )..where((t) => t.id.equals(kBingImageOfDayProviderId)))
            .getSingleOrNull();
    if (setting == null || !setting.enabled) {
      AppDebugLog.provider('bing_iotd: skip (disabled)');
      return;
    }

    final nowMs = _nowMs();

    if (setting.pollSeconds > 0) {
      final lastRow =
          await (ctx.db.select(
                ctx.db.configKeyValues,
              )..where((t) => t.key.equals(kBingImageOfDayLastCollectKvKey)))
              .getSingleOrNull();
      final last = int.tryParse(lastRow?.value ?? '') ?? 0;
      if (nowMs - last < setting.pollSeconds * 1000) {
        AppDebugLog.provider(
          'bing_iotd: skip poll (${setting.pollSeconds}s gate, lastMs=$last)',
        );
        return;
      }
    }

    late final ProviderRuntimeConfig config;
    try {
      config = await ctx.resolveConfig(kBingImageOfDayProviderId);
    } on Object catch (e, st) {
      AppDebugLog.providerFail('bing_iotd: resolveConfig', e, st);
      return;
    }

    final extra = BingImageOfDayExtraConfig.parse(config.configJson);
    final base = normalizeBingBaseUrl(config.baseUrl);
    final referer = base;

    AppDebugLog.provider(
      'bing_iotd: collect base=${AppDebugLog.safeHttpUri(Uri.parse(base))} '
      'mkt=${extra.market} resolution=${extra.resolution} category=${extra.category}',
    );

    try {
      await _pruneBingPhotosPastRetention(ctx, nowMs, extra.retentionDays);

      final archiveUri = _archiveUri(base, extra.market);
      Map<String, dynamic>? archiveJson;
      try {
        AppDebugLog.provider(
          'bing_iotd: GET ${AppDebugLog.safeHttpUri(archiveUri)}',
        );
        final res = await _bingGet(archiveUri, referer);
        if (res.statusCode != 200) {
          AppDebugLog.provider(
            'bing_iotd: archive status=${res.statusCode}',
          );
          return;
        }
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          archiveJson = decoded;
        }
      } on Object catch (e, st) {
        AppDebugLog.providerFail('bing_iotd: archive GET', e, st);
        return;
      }

      final images = archiveJson?['images'];
      if (images is! List<dynamic> || images.isEmpty) {
        AppDebugLog.provider('bing_iotd: no images in archive');
        return;
      }
      final first = images.first;
      if (first is! Map<String, dynamic>) {
        AppDebugLog.provider('bing_iotd: first image not an object');
        return;
      }
      final img = Map<String, dynamic>.from(first);

      final startdate = '${img['startdate'] ?? ''}'.trim();
      if (startdate.isEmpty) {
        AppDebugLog.provider('bing_iotd: missing startdate');
        return;
      }

      final photoId = 'bing_${startdate}_${extra.market}';
      final exists =
          await (ctx.db.select(
                ctx.db.photos,
              )..where((t) => t.id.equals(photoId)))
              .getSingleOrNull();
      if (exists != null) {
        AppDebugLog.provider('bing_iotd: already have id=$photoId');
        await ctx.db.into(ctx.db.configKeyValues).insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kBingImageOfDayLastCollectKvKey,
            value: '$nowMs',
          ),
        );
        return;
      }

      final urlbase = '${img['urlbase'] ?? ''}'.trim();
      if (urlbase.isEmpty || !urlbase.startsWith('/')) {
        AppDebugLog.provider('bing_iotd: bad urlbase');
        return;
      }

      final imageUrl = buildBingWallpaperImageUrl(
        base,
        urlbase,
        extra.resolution,
      );
      final imageUri = Uri.parse(imageUrl);

      List<int>? bytes;
      try {
        AppDebugLog.provider(
          'bing_iotd: GET image ${AppDebugLog.safeHttpUri(imageUri)}',
        );
        final imgRes = await _bingGet(imageUri, referer);
        if (imgRes.statusCode != 200 || imgRes.bodyBytes.isEmpty) {
          AppDebugLog.provider(
            'bing_iotd: image status=${imgRes.statusCode} bytes=${imgRes.bodyBytes.length}',
          );
          return;
        }
        bytes = imgRes.bodyBytes;
      } on Object catch (e, st) {
        AppDebugLog.providerFail('bing_iotd: image GET', e, st);
        return;
      }

      final title = '${img['title'] ?? ''}'.trim();
      final copyright = '${img['copyright'] ?? ''}'.trim();
      final copyrightLink = '${img['copyrightlink'] ?? ''}'.trim();
      final photographer = _photographerFromCopyright(copyright);

      final logicalKey = 'bing_iotd/$photoId/image';
      final ref = await ctx.blobs.putBytes(bytes, logicalKey: logicalKey);
      const mime = 'image/jpeg';

      await ctx.db.into(ctx.db.blobMetadata).insertOnConflictUpdate(
        BlobMetadataCompanion.insert(
          blobKey: logicalKey,
          sha256: ref.storageKey.split('/').last,
          relativePath: ref.storageKey,
          bytes: bytes.length,
          mimeType: const Value(mime),
          capturedAt: DateTime.fromMillisecondsSinceEpoch(nowMs),
        ),
      );

      final rejectCtx = await RejectFilterContext.loadFromDb(ctx.db);
      final blocked = rejectCtx.isMediaRejected(
        photographer: photographer,
        altText: title,
        urls: [copyrightLink],
      );

      await ctx.db.into(ctx.db.photos).insert(
        PhotosCompanion.insert(
          id: photoId,
          category: Value(extra.category),
          dataProvider: Value(kMediaDataProviderBing),
          mediaBlobKey: logicalKey,
          photographerName: photographer,
          photographerUrl: '',
          pexelsPageUrl: copyrightLink,
          altText: Value(title),
          fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(nowMs),
          suppressed: Value(blocked),
        ),
      );

      await ctx.db.into(ctx.db.configKeyValues).insertOnConflictUpdate(
        ConfigKeyValuesCompanion.insert(
          key: kBingImageOfDayLastCollectKvKey,
          value: '$nowMs',
        ),
      );
      AppDebugLog.provider(
        'bing_iotd: stored photo id=$photoId bytes=${bytes.length}',
      );
    } on Object catch (e, st) {
      AppDebugLog.providerFail('bing_iotd: collect', e, st);
    }
  }

  Future<void> _pruneBingPhotosPastRetention(
    DataWriteContext ctx,
    int nowMs,
    int retentionDays,
  ) async {
    if (retentionDays <= 0) {
      return;
    }
    final cutoffMs = nowMs - Duration(days: retentionDays).inMilliseconds;
    final cutoff = DateTime.fromMillisecondsSinceEpoch(cutoffMs);
    final rows =
        await (ctx.db.select(
              ctx.db.photos,
            )..where(
                (t) =>
                    t.dataProvider.equals(kMediaDataProviderBing) &
                    t.fetchedAtMs.isSmallerThanValue(cutoff),
              ))
            .get();
    for (final row in rows) {
      await _deleteBingPhoto(ctx, row);
    }
  }

  Future<void> _deleteBingPhoto(DataWriteContext ctx, Photo row) async {
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
}
