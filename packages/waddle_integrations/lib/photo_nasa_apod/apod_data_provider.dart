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
import 'apod_extra_config.dart';

const String kPhotoNasaApodIntegrationType = 'photo_nasa_apod';

class NasaApodDataProvider implements IDataProvider {
  NasaApodDataProvider({
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
  String get id => kPhotoNasaApodIntegrationType;

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
          'nasa_apod: skip poll ($integrationId ${setting.pollSeconds}s gate)',
        );
        return;
      }
    }

    late final ProviderRuntimeConfig config;
    try {
      config = await ctx.resolveConfig(integrationId);
    } on Object catch (e, st) {
      ctx.diagnostics.providerFail('nasa_apod: resolveConfig', e, st);
      return;
    }

    final apiKey = config.accessToken;
    if (apiKey == null || apiKey.isEmpty) {
      ctx.diagnostics.provider('nasa_apod: skip (no API key) id=$integrationId');
      return;
    }

    final extra = ApodExtraConfig.parse(config.configJson);
    final base = normalizeNasaBaseUrl(config.baseUrl);

    try {
      await pruneNasaPhotosByRetention(
        ctx,
        dataProvider: kMediaDataProviderPhotoNasaApod,
        retentionDays: extra.retentionDays,
        nowMs: nowMs,
      );

      final dates = <String>[];
      for (var i = 0; i <= extra.backfillDays; i++) {
        final day = nowUtc.subtract(Duration(days: i));
        dates.add(formatUtcDate(day));
      }

      var stored = 0;
      for (final date in dates) {
        final photoId = 'apod_$date';
        final exists = await (ctx.db.select(ctx.db.photos)
              ..where((t) => t.id.equals(photoId)))
            .getSingleOrNull();
        if (exists != null) {
          continue;
        }

        final uri = buildNasaApiUri(
          baseUrl: base,
          path: '/planetary/apod',
          apiKey: apiKey,
          query: {
            'date': date,
            if (extra.hd) 'hd': 'true',
          },
        );
        ctx.diagnostics.provider('nasa_apod: GET ${safeHttpUriForLog(uri)}');

        final res = await _http.get(uri).timeout(_requestTimeout);
        logNasaRateLimitHeaders(ctx.diagnostics, res);
        if (res.statusCode != 200) {
          ctx.diagnostics.provider(
            'nasa_apod: status=${res.statusCode} date=$date',
          );
          continue;
        }

        final decoded = jsonDecode(res.body);
        if (decoded is! Map<String, dynamic>) {
          continue;
        }
        final mediaType = '${decoded['media_type'] ?? ''}'.trim().toLowerCase();
        if (mediaType != 'image') {
          ctx.diagnostics.provider(
            'nasa_apod: skip non-image media_type=$mediaType date=$date',
          );
          continue;
        }

        final imageUrl = extra.hd
            ? '${decoded['hdurl'] ?? ''}'.trim()
            : '${decoded['url'] ?? ''}'.trim();
        if (imageUrl.isEmpty) {
          final fallback = '${decoded['url'] ?? ''}'.trim();
          if (fallback.isEmpty) {
            continue;
          }
        }
        final downloadUrl = imageUrl.isNotEmpty
            ? imageUrl
            : '${decoded['url'] ?? ''}'.trim();

        List<int> bytes;
        try {
          final imgRes =
              await _http.get(Uri.parse(downloadUrl)).timeout(_requestTimeout);
          if (imgRes.statusCode != 200 || imgRes.bodyBytes.isEmpty) {
            ctx.diagnostics.provider(
              'nasa_apod: image status=${imgRes.statusCode} date=$date',
            );
            continue;
          }
          bytes = imgRes.bodyBytes;
        } on Object catch (e, st) {
          ctx.diagnostics.providerFail('nasa_apod: image GET date=$date', e, st);
          continue;
        }

        final title = '${decoded['title'] ?? ''}'.trim();
        final explanation = truncateAltText('${decoded['explanation'] ?? ''}');
        final copyright = '${decoded['copyright'] ?? ''}'.trim();
        final photographer =
            copyright.isEmpty ? 'NASA APOD' : 'NASA APOD ($copyright)';

        await storeNasaPhoto(
          ctx: ctx,
          photoId: photoId,
          dataProvider: kMediaDataProviderPhotoNasaApod,
          category: extra.category,
          bytes: bytes,
          logicalKey: 'nasa_apod/$photoId/image',
          photographerName: photographer,
          pageUrl: apodPageUrlForDate(date),
          altText: title.isEmpty ? explanation : '$title — $explanation',
          nowMs: nowMs,
        );
        stored++;
      }

      await kv.upsertIntegration(
        integrationId: integrationId,
        key: kIntegrationLastCollectKey,
        value: '$nowMs',
        valueType: kIntegrationKvTypeIntMs,
      );
      ctx.diagnostics.provider('nasa_apod: stored $stored new photo(s)');
    } on Object catch (e, st) {
      ctx.diagnostics.providerFail('nasa_apod: collect', e, st);
    }
  }
}
