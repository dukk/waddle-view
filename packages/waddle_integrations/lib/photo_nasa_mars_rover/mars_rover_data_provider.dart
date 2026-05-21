import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:waddle_shared/config/provider_runtime_config.dart';
import 'package:waddle_shared/collect/data_provider.dart';
import 'package:waddle_shared/collect/data_write_context.dart';
import 'package:waddle_shared/integrations/integration_collect.dart';
import 'package:waddle_shared/integrations/integration_kv_repository.dart';
import 'package:waddle_shared/integrations/integration_kv_types.dart';
import 'package:waddle_shared/net/http_debug_uri.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';

import '../nasa/nasa_http.dart';
import '../nasa/nasa_photo_collect.dart';
import 'mars_rover_extra_config.dart';

const String kPhotoNasaMarsRoverIntegrationType = 'photo_nasa_mars_rover';

class NasaMarsRoverDataProvider implements IDataProvider {
  NasaMarsRoverDataProvider({
    http.Client? httpClient,
    DateTime Function()? nowUtc,
    Duration? requestTimeout,
  })  : _http = httpClient ?? http.Client(),
        _nowUtc = nowUtc ?? (() => DateTime.now().toUtc()),
        _requestTimeout = requestTimeout ?? kNasaHttpTimeout;

  final http.Client _http;
  final DateTime Function() _nowUtc;
  final Duration _requestTimeout;

  @override
  String get id => kPhotoNasaMarsRoverIntegrationType;

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
    final nowUtc = _nowUtc();
    final nowMs = nowUtc.millisecondsSinceEpoch;
    final kv = IntegrationKvRepository(ctx.db);

    if (setting.pollSeconds > 0) {
      final lastValue =
          await kv.getIntegrationValue(integrationId, kIntegrationLastCollectKey);
      final last = int.tryParse(lastValue ?? '') ?? 0;
      if (nowMs - last < setting.pollSeconds * 1000) {
        ctx.diagnostics.provider(
          'nasa_mars: skip poll ($integrationId ${setting.pollSeconds}s gate)',
        );
        return;
      }
    }

    late final ProviderRuntimeConfig config;
    try {
      config = await ctx.resolveConfig(integrationId);
    } on Object catch (e, st) {
      ctx.diagnostics.providerFail('nasa_mars: resolveConfig', e, st);
      return;
    }

    final apiKey = config.accessToken;
    if (apiKey == null || apiKey.isEmpty) {
      ctx.diagnostics.provider('nasa_mars: skip (no API key) id=$integrationId');
      return;
    }

    final extra = MarsRoverExtraConfig.parse(config.configJson);
    final base = normalizeNasaBaseUrl(config.baseUrl);

    try {
      await pruneNasaPhotosByRetention(
        ctx,
        dataProvider: kMediaDataProviderPhotoNasaMarsRover,
        retentionDays: extra.retentionDays,
        nowMs: nowMs,
      );
      await pruneNasaPhotosByMaxCount(
        ctx,
        dataProvider: kMediaDataProviderPhotoNasaMarsRover,
        maxPhotos: extra.maxPhotos,
      );

      var stored = 0;
      for (final rover in extra.rovers) {
        if (stored >= extra.photosPerCollect * extra.rovers.length) {
          break;
        }
        final added = await _collectRover(
          ctx,
          base: base,
          apiKey: apiKey,
          rover: rover,
          extra: extra,
          nowMs: nowMs,
          nowUtc: nowUtc,
          budget: extra.photosPerCollect,
        );
        stored += added;
      }

      await kv.upsertIntegration(
        integrationId: integrationId,
        key: kIntegrationLastCollectKey,
        value: '$nowMs',
        valueType: kIntegrationKvTypeIntMs,
      );
      ctx.diagnostics.provider('nasa_mars: stored $stored new photo(s)');
    } on Object catch (e, st) {
      ctx.diagnostics.providerFail('nasa_mars: collect', e, st);
    }
  }

  Future<int> _collectRover(
    DataWriteContext ctx, {
    required String base,
    required String apiKey,
    required String rover,
    required MarsRoverExtraConfig extra,
    required int nowMs,
    required DateTime nowUtc,
    required int budget,
  }) async {
    var stored = 0;
    for (var dayOffset = 1; dayOffset <= extra.maxDaysBack; dayOffset++) {
      if (stored >= budget) {
        break;
      }
      final earthDate = formatUtcDate(
        nowUtc.subtract(Duration(days: dayOffset)),
      );
      final uri = buildNasaApiUri(
        baseUrl: base,
        path: '/mars-photos/api/v1/rovers/$rover/photos',
        apiKey: apiKey,
        query: {'earth_date': earthDate},
      );
      ctx.diagnostics.provider(
        'nasa_mars: GET ${safeHttpUriForLog(uri)}',
      );

      final res = await _http.get(uri).timeout(_requestTimeout);
      logNasaRateLimitHeaders(ctx.diagnostics, res);
      if (res.statusCode != 200) {
        ctx.diagnostics.provider(
          'nasa_mars: status=${res.statusCode} rover=$rover date=$earthDate',
        );
        continue;
      }

      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) {
        continue;
      }
      final photos = decoded['photos'];
      if (photos is! List || photos.isEmpty) {
        continue;
      }

      for (final item in photos) {
        if (stored >= budget) {
          break;
        }
        if (item is! Map<String, dynamic>) {
          continue;
        }
        final nasaId = item['id'];
        if (nasaId == null) {
          continue;
        }
        final photoId = 'mars_${rover}_$nasaId';
        final exists = await (ctx.db.select(ctx.db.photos)
              ..where((t) => t.id.equals(photoId)))
            .getSingleOrNull();
        if (exists != null) {
          continue;
        }

        final imageUrl = _pickImageUrl(item);
        if (imageUrl == null) {
          continue;
        }

        List<int> bytes;
        try {
          final imgRes =
              await _http.get(Uri.parse(imageUrl)).timeout(_requestTimeout);
          if (imgRes.statusCode != 200 || imgRes.bodyBytes.isEmpty) {
            continue;
          }
          bytes = imgRes.bodyBytes;
        } on Object catch (e, st) {
          ctx.diagnostics.providerFail(
            'nasa_mars: image GET rover=$rover id=$nasaId',
            e,
            st,
          );
          continue;
        }

        final camera = item['camera'];
        final cameraName = camera is Map
            ? '${camera['full_name'] ?? camera['name'] ?? ''}'.trim()
            : '';
        final roverObj = item['rover'];
        final roverLabel = roverObj is Map
            ? '${roverObj['name'] ?? rover}'.trim()
            : rover;
        final photographer = cameraName.isEmpty
            ? 'NASA Mars $roverLabel'
            : 'NASA Mars $roverLabel ($cameraName)';

        await storeNasaPhoto(
          ctx: ctx,
          photoId: photoId,
          dataProvider: kMediaDataProviderPhotoNasaMarsRover,
          category: extra.categoryForRover(rover),
          bytes: bytes,
          logicalKey: 'nasa_mars/$photoId/image',
          photographerName: photographer,
          pageUrl: imageUrl,
          altText: '${roverLabel} — $earthDate',
          nowMs: nowMs,
        );
        stored++;
      }

      if (stored > 0) {
        break;
      }
    }
    return stored;
  }

  String? _pickImageUrl(Map<String, dynamic> photo) {
    for (final key in ['large', 'medium', 'small']) {
      final url = '${photo[key] ?? ''}'.trim();
      if (url.isNotEmpty) {
        return url;
      }
    }
    final src = '${photo['img_src'] ?? ''}'.trim();
    return src.isEmpty ? null : src;
  }
}
