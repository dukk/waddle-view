import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;

import '../../../debug/app_debug_log.dart';
import '../../../persistence/tables.dart';
import '../../data_provider.dart';
import '../../data_write_context.dart';
import 'flickr_media_extra_config.dart';

const String kFlickrMediaProviderId = 'flickr_media';
const String kDefaultFlickrBaseUrl = 'https://api.flickr.com/services/rest';
const String kFlickrLastCollectKvKey = 'provider.flickr_media.last_collect_ms';

class FlickrMediaDataProvider implements IDataProvider {
  FlickrMediaDataProvider({http.Client? httpClient, int Function()? nowMs})
      : _http = httpClient ?? http.Client(),
        _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  final http.Client _http;
  final int Function() _nowMs;

  @override
  String get id => kFlickrMediaProviderId;

  @override
  Future<void> collect(DataWriteContext ctx) async {
    final setting =
        await (ctx.db.select(
              ctx.db.providerSettings,
            )..where((t) => t.id.equals(kFlickrMediaProviderId)))
            .getSingleOrNull();
    if (setting == null || !setting.enabled) {
      AppDebugLog.provider('flickr_media: skip (disabled)');
      return;
    }
    final nowMs = _nowMs();
    if (setting.pollSeconds > 0) {
      final lastRow =
          await (ctx.db.select(
                ctx.db.configKeyValues,
              )..where((t) => t.key.equals(kFlickrLastCollectKvKey)))
              .getSingleOrNull();
      final last = int.tryParse(lastRow?.value ?? '') ?? 0;
      if (nowMs - last < setting.pollSeconds * 1000) {
        AppDebugLog.provider('flickr_media: skip poll gate');
        return;
      }
    }

    final config = await ctx.resolveConfig(kFlickrMediaProviderId);
    final apiKey = config.accessToken;
    if (apiKey == null || apiKey.isEmpty) {
      AppDebugLog.provider('flickr_media: skip (no API key)');
      return;
    }
    final extra = FlickrMediaExtraConfig.parse(config.configJson);
    if (extra.groupIds.isEmpty) {
      AppDebugLog.provider('flickr_media: skip (no groupIds configured)');
      await _markCollected(ctx, nowMs);
      return;
    }

    final base = _normalizeBase(config.baseUrl);
    var remaining = extra.perPollLimit;
    for (final groupId in extra.groupIds) {
      if (remaining <= 0) {
        break;
      }
      final photos = await _fetchGroupPhotos(
        base: base,
        apiKey: apiKey,
        groupId: groupId,
        perPage: remaining.clamp(1, 500),
        sort: extra.sort,
      );
      for (final photo in photos) {
        if (remaining <= 0) {
          break;
        }
        final ok = await _tryInsertPhoto(
          ctx,
          photo: photo,
          category: extra.category,
          nowMs: nowMs,
        );
        if (ok) {
          remaining--;
        }
      }
    }
    await _markCollected(ctx, nowMs);
  }

  String _normalizeBase(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return kDefaultFlickrBaseUrl;
    }
    return raw.trim().replaceAll(RegExp(r'/$'), '');
  }

  Future<void> _markCollected(DataWriteContext ctx, int nowMs) async {
    await ctx.db.into(ctx.db.configKeyValues).insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kFlickrLastCollectKvKey,
            value: '$nowMs',
          ),
        );
  }

  Future<List<Map<String, dynamic>>> _fetchGroupPhotos({
    required String base,
    required String apiKey,
    required String groupId,
    required int perPage,
    required String sort,
  }) async {
    try {
      final uri = Uri.parse(base).replace(
        queryParameters: {
          'method': 'flickr.groups.pools.getPhotos',
          'api_key': apiKey,
          'group_id': groupId,
          'format': 'json',
          'nojsoncallback': '1',
          'per_page': '$perPage',
          'page': '1',
          'sort': sort,
          'extras':
              'owner_name,date_upload,date_taken,url_o,url_l,url_c,url_z,url_m,width_o,height_o,width_l,height_l,width_c,height_c,width_z,height_z,width_m,height_m',
        },
      );
      AppDebugLog.provider('flickr_media: GET ${AppDebugLog.safeHttpUri(uri)}');
      final res = await _http.get(uri);
      if (res.statusCode != 200) {
        AppDebugLog.provider('flickr_media: list status=${res.statusCode}');
        return const [];
      }
      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) {
        return const [];
      }
      if (decoded['stat'] != 'ok') {
        return const [];
      }
      final photosMap = decoded['photos'];
      if (photosMap is! Map<String, dynamic>) {
        return const [];
      }
      final raw = photosMap['photo'];
      if (raw is! List<dynamic>) {
        return const [];
      }
      final out = <Map<String, dynamic>>[];
      for (final p in raw) {
        if (p is Map) {
          out.add(Map<String, dynamic>.from(p));
        }
      }
      return out;
    } on Object catch (e, st) {
      AppDebugLog.providerFail('flickr_media: fetchGroupPhotos', e, st);
      return const [];
    }
  }

  String? _pickPhotoUrl(Map<String, dynamic> photo) {
    const keys = ['url_o', 'url_l', 'url_c', 'url_z', 'url_m'];
    for (final key in keys) {
      final url = photo[key];
      if (url is String && url.isNotEmpty) {
        return url;
      }
    }
    return null;
  }

  int? _dimension(Map<String, dynamic> photo, String key) {
    final v = photo[key];
    if (v is int) {
      return v > 0 ? v : null;
    }
    if (v is num) {
      final i = v.toInt();
      return i > 0 ? i : null;
    }
    if (v is String) {
      final i = int.tryParse(v);
      if (i != null && i > 0) {
        return i;
      }
    }
    return null;
  }

  Future<bool> _tryInsertPhoto(
    DataWriteContext ctx, {
    required Map<String, dynamic> photo,
    required String category,
    required int nowMs,
  }) async {
    final idRaw = photo['id'];
    if (idRaw == null) {
      return false;
    }
    final id = '$idRaw'.trim();
    if (id.isEmpty) {
      return false;
    }
    final rowId = 'flickr:$id';
    final existing =
        await (ctx.db.select(ctx.db.photos)..where((t) => t.id.equals(rowId)))
            .getSingleOrNull();
    if (existing != null) {
      return false;
    }
    final mediaUrl = _pickPhotoUrl(photo);
    if (mediaUrl == null) {
      return false;
    }
    final mediaRes = await _http.get(Uri.parse(mediaUrl));
    if (mediaRes.statusCode != 200 || mediaRes.bodyBytes.isEmpty) {
      return false;
    }
    final owner = (photo['ownername'] ?? '').toString();
    final title = (photo['title'] ?? '').toString();
    final ownerId = (photo['owner'] ?? '').toString();
    final pageUrl = ownerId.isEmpty
        ? ''
        : 'https://www.flickr.com/photos/$ownerId/$id';
    final logicalKey = 'flickr/photo/$id/image';
    final ref = await ctx.blobs.putBytes(mediaRes.bodyBytes, logicalKey: logicalKey);
    final mime = _mimeFromUrl(mediaUrl);
    final pixelW = _dimension(photo, 'width_o') ??
        _dimension(photo, 'width_l') ??
        _dimension(photo, 'width_c') ??
        _dimension(photo, 'width_z') ??
        _dimension(photo, 'width_m');
    final pixelH = _dimension(photo, 'height_o') ??
        _dimension(photo, 'height_l') ??
        _dimension(photo, 'height_c') ??
        _dimension(photo, 'height_z') ??
        _dimension(photo, 'height_m');

    await ctx.db.into(ctx.db.blobMetadata).insertOnConflictUpdate(
          BlobMetadataCompanion.insert(
            blobKey: logicalKey,
            sha256: ref.storageKey.split('/').last,
            relativePath: ref.storageKey,
            bytes: mediaRes.bodyBytes.length,
            mimeType: Value(mime),
            capturedAt: DateTime.fromMillisecondsSinceEpoch(nowMs),
            pixelWidth: pixelW != null ? Value(pixelW) : const Value.absent(),
            pixelHeight: pixelH != null ? Value(pixelH) : const Value.absent(),
          ),
        );
    await ctx.db.into(ctx.db.photos).insert(
          PhotosCompanion.insert(
            id: rowId,
            category: Value(category),
            dataProvider: const Value(kMediaDataProviderFlickr),
            mediaBlobKey: logicalKey,
            photographerName: owner,
            photographerUrl: ownerId.isEmpty ? '' : 'https://www.flickr.com/people/$ownerId',
            pexelsPageUrl: pageUrl,
            altText: Value(title),
            fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(nowMs),
          ),
        );
    return true;
  }

  String _mimeFromUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    if (lower.endsWith('.gif')) {
      return 'image/gif';
    }
    return 'image/jpeg';
  }
}
