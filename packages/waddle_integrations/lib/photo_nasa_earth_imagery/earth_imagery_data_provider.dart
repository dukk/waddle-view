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
import '../weather_openweathermap/weather_locations_for_collect.dart';
import 'earth_imagery_extra_config.dart';

const String kPhotoNasaEarthImageryIntegrationType = 'photo_nasa_earth_imagery';

class NasaEarthImageryDataProvider implements IDataProvider {
  NasaEarthImageryDataProvider({
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
  String get id => kPhotoNasaEarthImageryIntegrationType;

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
          'nasa_earth: skip poll ($integrationId ${setting.pollSeconds}s gate)',
        );
        return;
      }
    }

    late final ProviderRuntimeConfig config;
    try {
      config = await ctx.resolveConfig(integrationId);
    } on Object catch (e, st) {
      ctx.diagnostics.providerFail('nasa_earth: resolveConfig', e, st);
      return;
    }

    final apiKey = config.accessToken;
    if (apiKey == null || apiKey.isEmpty) {
      ctx.diagnostics.provider(
        'nasa_earth: skip (no API key) id=$integrationId',
      );
      return;
    }

    final extra = EarthImageryExtraConfig.parse(config.configJson);
    final base = normalizeNasaBaseUrl(config.baseUrl);
    final endDate = formatUtcDate(nowUtc);
    final beginDate = formatUtcDate(
      nowUtc.subtract(Duration(days: extra.lookbackDays)),
    );

    try {
      await pruneNasaPhotosByRetention(
        ctx,
        dataProvider: kMediaDataProviderPhotoNasaEarthImagery,
        retentionDays: extra.retentionDays,
        nowMs: nowMs,
      );

      final locations = await resolveWeatherLocationsForCollect(
        ctx.db,
        extra.defaultLocation,
      );

      var stored = 0;
      for (final location in locations) {
        await ensureSyntheticDefaultInterestsLocation(ctx.db, location);
        final added = await _collectLocation(
          ctx,
          base: base,
          apiKey: apiKey,
          location: location,
          extra: extra,
          beginDate: beginDate,
          endDate: endDate,
          nowMs: nowMs,
        );
        stored += added;
      }

      await kv.upsertIntegration(
        integrationId: integrationId,
        key: kIntegrationLastCollectKey,
        value: '$nowMs',
        valueType: kIntegrationKvTypeIntMs,
      );
      ctx.diagnostics.provider(
        'nasa_earth: stored $stored new photo(s) locations=${locations.length}',
      );
    } on Object catch (e, st) {
      ctx.diagnostics.providerFail('nasa_earth: collect', e, st);
    }
  }

  Future<int> _collectLocation(
    DataWriteContext ctx, {
    required String base,
    required String apiKey,
    required WeatherCollectLocation location,
    required EarthImageryExtraConfig extra,
    required String beginDate,
    required String endDate,
    required int nowMs,
  }) async {
    final assetsUri = buildNasaApiUri(
      baseUrl: base,
      path: '/planetary/earth/assets',
      apiKey: apiKey,
      query: {
        'lat': '${location.lat}',
        'lon': '${location.lon}',
        'begin': beginDate,
        'end': endDate,
      },
    );
    ctx.diagnostics.provider(
      'nasa_earth: GET assets ${safeHttpUriForLog(assetsUri)} id=${location.id}',
    );

    final assetsRes = await _http.get(assetsUri).timeout(_requestTimeout);
    logNasaRateLimitHeaders(ctx.diagnostics, assetsRes);
    if (assetsRes.statusCode != 200) {
      ctx.diagnostics.provider(
        'nasa_earth: assets status=${assetsRes.statusCode} id=${location.id}',
      );
      return 0;
    }

    final assetsDecoded = jsonDecode(assetsRes.body);
    if (assetsDecoded is! Map<String, dynamic>) {
      return 0;
    }
    final results = assetsDecoded['results'];
    if (results is! List || results.isEmpty) {
      ctx.diagnostics.provider(
        'nasa_earth: no assets id=${location.id}',
      );
      return 0;
    }

    final latest = results.last;
    if (latest is! Map<String, dynamic>) {
      return 0;
    }
    final dateIso = '${latest['date'] ?? ''}'.trim();
    if (dateIso.isEmpty) {
      return 0;
    }
    final assetDate = earthAssetDateFromIso(dateIso);
    final photoId = 'earth_${location.id}_$assetDate';
    final exists = await (ctx.db.select(ctx.db.photos)
          ..where((t) => t.id.equals(photoId)))
        .getSingleOrNull();
    if (exists != null) {
      return 0;
    }

    final imageryUri = buildNasaApiUri(
      baseUrl: base,
      path: '/planetary/earth/imagery',
      apiKey: apiKey,
      query: {
        'lat': '${location.lat}',
        'lon': '${location.lon}',
        'date': assetDate,
        'dim': '${extra.dim}',
      },
    );
    ctx.diagnostics.provider(
      'nasa_earth: GET imagery ${safeHttpUriForLog(imageryUri)}',
    );

    final imageryRes = await _http.get(imageryUri).timeout(_requestTimeout);
    logNasaRateLimitHeaders(ctx.diagnostics, imageryRes);
    if (imageryRes.statusCode != 200) {
      ctx.diagnostics.provider(
        'nasa_earth: imagery status=${imageryRes.statusCode} id=${location.id}',
      );
      return 0;
    }

    final imageryDecoded = jsonDecode(imageryRes.body);
    if (imageryDecoded is! Map<String, dynamic>) {
      return 0;
    }
    var downloadUrl = '${imageryDecoded['url'] ?? ''}'.trim();
    if (downloadUrl.isEmpty) {
      return 0;
    }

    // NASA returns a URL that may need api_key appended for download.
    final downloadUri = Uri.parse(downloadUrl);
    if (!downloadUri.queryParameters.containsKey('api_key')) {
      downloadUrl = downloadUri.replace(
        queryParameters: {
          ...downloadUri.queryParameters,
          'api_key': apiKey,
        },
      ).toString();
    }

    List<int> bytes;
    try {
      final imgRes =
          await _http.get(Uri.parse(downloadUrl)).timeout(_requestTimeout);
      if (imgRes.statusCode != 200 || imgRes.bodyBytes.isEmpty) {
        ctx.diagnostics.provider(
          'nasa_earth: image status=${imgRes.statusCode} id=${location.id}',
        );
        return 0;
      }
      bytes = imgRes.bodyBytes;
    } on Object catch (e, st) {
      ctx.diagnostics.providerFail(
        'nasa_earth: image GET id=${location.id}',
        e,
        st,
      );
      return 0;
    }

    await storeNasaPhoto(
      ctx: ctx,
      photoId: photoId,
      dataProvider: kMediaDataProviderPhotoNasaEarthImagery,
      category: extra.category,
      bytes: bytes,
      logicalKey: 'nasa_earth/$photoId/image',
      photographerName: 'NASA/USGS Landsat',
      pageUrl: downloadUrl,
      altText: '${location.name} — $assetDate',
      nowMs: nowMs,
    );
    return 1;
  }
}
