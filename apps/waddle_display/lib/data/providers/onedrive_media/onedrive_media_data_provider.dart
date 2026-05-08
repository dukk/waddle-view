import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;

import '../../../blob/blob_store.dart';
import '../../../config/microsoft_graph_kv.dart';
import '../../../debug/app_debug_log.dart';
import '../../../persistence/database.dart';
import '../../../persistence/tables.dart';
import '../../../secrets/secret_store.dart';
import '../../data_provider.dart';
import '../../data_write_context.dart';
import '../microsoft_graph/microsoft_graph_oauth.dart'
    show MicrosoftGraphOAuth, kMicrosoftGraphAccessTokenSkewMs;
import 'onedrive_media_extra_config.dart';

const String kOneDriveMediaProviderId = 'onedrive_media';

const String kDefaultGraphBaseUrl = 'https://graph.microsoft.com/v1.0';

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

void _logGraphJsonError(String context, String body) {
  try {
    final j = jsonDecode(body);
    if (j is Map<String, dynamic> && j['error'] is Map<String, dynamic>) {
      final e = j['error'] as Map<String, dynamic>;
      AppDebugLog.provider(
        '$context Graph error code=${e['code']} message=${e['message']}',
      );
      return;
    }
  } on Object {
    // fall through
  }
  final t = body.trim().replaceAll(RegExp(r'\s+'), ' ');
  AppDebugLog.provider(
    '$context body=${t.length <= 400 ? t : '${t.substring(0, 400)}…'}',
  );
}

/// Syncs photos/videos from OneDrive folders into [Photos] / [Videos] via Graph.
class OneDriveMediaDataProvider implements IDataProvider {
  factory OneDriveMediaDataProvider({
    http.Client? httpClient,
    int Function()? nowMs,
    MicrosoftGraphOAuth? oauth,
  }) {
    final client = httpClient ?? http.Client();
    final clock =
        nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);
    return OneDriveMediaDataProvider._(
      client,
      clock,
      oauth ?? MicrosoftGraphOAuth(httpClient: client, nowMs: clock),
    );
  }

  OneDriveMediaDataProvider._(this._http, this._nowMs, this._oauth);

  final http.Client _http;
  final int Function() _nowMs;
  final MicrosoftGraphOAuth _oauth;

  @override
  String get id => kOneDriveMediaProviderId;

  Future<bool> _shouldSkipForPollWindowOnly(
    AppDatabase db,
    SecretStore secrets,
    OneDriveMediaExtraConfig extra,
    int nowMs,
    int pollSeconds,
  ) async {
    if (pollSeconds <= 0) {
      return false;
    }
    final lastRow =
        await (db.select(db.configKeyValues)
              ..where((t) => t.key.equals(kOneDriveMediaLastCollectKvKey)))
            .getSingleOrNull();
    final last = int.tryParse(lastRow?.value ?? '') ?? 0;
    if (nowMs - last >= pollSeconds * 1000) {
      return false;
    }

    for (final a in extra.accounts) {
      if (a.sources.isEmpty) {
        continue;
      }
      final access =
          await secrets.read(microsoftGraphAccessTokenSecret(a.graphAccountKey));
      final expiresRow =
          await (db.select(db.configKeyValues)
                ..where(
                  (t) => t.key.equals(
                    kMicrosoftGraphAccessTokenExpiresAtKvKey(a.graphAccountKey),
                  ),
                ))
              .getSingleOrNull();
      final expiresAt = int.tryParse(expiresRow?.value ?? '') ?? 0;
      final fresh = access != null &&
          access.isNotEmpty &&
          expiresAt > nowMs + kMicrosoftGraphAccessTokenSkewMs;
      if (!fresh) {
        AppDebugLog.provider(
          'OneDriveMediaDataProvider: poll window bypass (auth needed for '
          '${a.graphAccountKey})',
        );
        return false;
      }
    }

    AppDebugLog.provider(
      'OneDriveMediaDataProvider: skip poll gate lastCollectMs=$last',
    );
    return true;
  }

  @override
  Future<void> collect(DataWriteContext ctx) async {
    final setting =
        await (ctx.db.select(
              ctx.db.providerSettings,
            )..where((t) => t.id.equals(kOneDriveMediaProviderId)))
            .getSingleOrNull();
    if (setting == null || !setting.enabled) {
      AppDebugLog.provider('onedrive_media: skip (disabled)');
      return;
    }

    final nowMs = _nowMs();

    final clientIdRow =
        await (ctx.db.select(
              ctx.db.configKeyValues,
            )..where((t) => t.key.equals(kMicrosoftGraphClientIdKvKey)))
            .getSingleOrNull();
    final clientId = clientIdRow?.value.trim() ?? '';
    if (clientId.isEmpty) {
      AppDebugLog.provider(
        'OneDriveMediaDataProvider: skip (no $kMicrosoftGraphClientIdKvKey)',
      );
      return;
    }

    final extra = OneDriveMediaExtraConfig.parse(setting.configJson);
    if (extra.accounts.isEmpty) {
      AppDebugLog.provider(
        'OneDriveMediaDataProvider: skip (no accounts in config_json)',
      );
      await _markCollectDone(ctx.db, nowMs);
      return;
    }

    if (await _shouldSkipForPollWindowOnly(
          ctx.db,
          ctx.secrets,
          extra,
          nowMs,
          setting.pollSeconds,
        )) {
      AppDebugLog.provider(
        'onedrive_media: skip poll gate pollSeconds=${setting.pollSeconds}',
      );
      return;
    }

    final graphBase = _normalizeGraphBase(setting.baseUrl);
    AppDebugLog.provider(
      'onedrive_media: collect graphBase=$graphBase accounts=${extra.accounts.length} '
      'globalLimit=${extra.globalPerPollLimit}',
    );
    var didSync = false;
    var globalRemaining = extra.globalPerPollLimit;

    try {
      for (final account in extra.accounts) {
        if (account.sources.isEmpty) {
          continue;
        }
        final token = await _oauth.ensureAccessToken(
          db: ctx.db,
          secrets: ctx.secrets,
          clientId: clientId,
          graphAccountKey: account.graphAccountKey,
        );
        if (token == null || token.isEmpty) {
          AppDebugLog.provider(
            'OneDriveMediaDataProvider: no token for ${account.graphAccountKey}',
          );
          continue;
        }

        for (final source in account.sources) {
          if (globalRemaining <= 0) {
            break;
          }
          final n = await _syncSource(
            ctx,
            graphBase: graphBase,
            accessToken: token,
            graphAccountKey: account.graphAccountKey,
            source: source,
            nowMs: nowMs,
            globalRemaining: globalRemaining,
          );
          globalRemaining -= n;
          didSync = true;
        }
        if (globalRemaining <= 0) {
          break;
        }
      }
      if (didSync) {
        AppDebugLog.provider('onedrive_media: collect ok, last_collect updated');
        await _markCollectDone(ctx.db, nowMs);
      } else {
        AppDebugLog.provider('onedrive_media: collect finished (no writes)');
      }
    } on Object catch (e, st) {
      AppDebugLog.providerFail('onedrive_media: collect', e, st);
    }
  }

  Future<void> _markCollectDone(AppDatabase db, int nowMs) async {
    await db.into(db.configKeyValues).insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: kOneDriveMediaLastCollectKvKey,
            value: '$nowMs',
          ),
        );
  }

  String _normalizeGraphBase(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return kDefaultGraphBaseUrl;
    }
    return raw.trim().replaceAll(RegExp(r'/$'), '');
  }

  /// Returns number of files downloaded this source.
  Future<int> _syncSource(
    DataWriteContext ctx, {
    required String graphBase,
    required String accessToken,
    required String graphAccountKey,
    required OneDriveMediaSourceSpec source,
    required int nowMs,
    required int globalRemaining,
  }) async {
    final perSourceCap = source.effectivePerPollLimit;
    var downloaded = 0;
    String? url = _childrenListUrl(graphBase, source.path);
    var childrenPage = 0;

    while (url != null && downloaded < perSourceCap && globalRemaining > 0) {
      final pageUrl = url;
      childrenPage++;
      final pageUri = Uri.parse(pageUrl);
      AppDebugLog.provider(
        'onedrive_media: GET children page=$childrenPage kind=${source.kind} '
        'category=${source.category} path=${source.path} '
        '${AppDebugLog.safeHttpUri(pageUri)}',
      );
      final res = await _http.get(
        pageUri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (res.statusCode != 200) {
        AppDebugLog.provider(
          'onedrive_media: children status=${res.statusCode} page=$childrenPage',
        );
        _logGraphJsonError('onedrive_media: children', res.body);
        break;
      }
      final m = jsonDecode(res.body) as Map<String, dynamic>;
      final values = m['value'];
      if (values is List<dynamic>) {
        AppDebugLog.provider(
          'onedrive_media: children page=$childrenPage items=${values.length}',
        );
        for (final rawItem in values) {
          if (downloaded >= perSourceCap || globalRemaining <= 0) {
            break;
          }
          if (rawItem is! Map<String, dynamic>) {
            continue;
          }
          final item = Map<String, dynamic>.from(rawItem);
          final id = item['id'];
          if (id is! String || id.isEmpty) {
            continue;
          }
          final file = item['file'];
          if (file is! Map<String, dynamic>) {
            continue;
          }
          final mime = file['mimeType'];
          if (mime is! String) {
            continue;
          }
          if (source.kind == 'photo' && !_isPhotoMime(mime)) {
            continue;
          }
          if (source.kind == 'video' && !_isVideoMime(mime)) {
            continue;
          }

          final rowId = kOneDriveMediaItemRowId(graphAccountKey, id);
          final dl = item['@microsoft.graph.downloadUrl'];
          if (dl is! String || dl.isEmpty) {
            continue;
          }

          if (source.kind == 'photo') {
            final ok = await _tryIngestPhoto(
              ctx,
              rowId: rowId,
              category: source.category,
              downloadUrl: dl,
              item: item,
              nowMs: nowMs,
            );
            if (ok) {
              downloaded++;
              globalRemaining--;
            }
          } else {
            final ok = await _tryIngestVideo(
              ctx,
              rowId: rowId,
              category: source.category,
              downloadUrl: dl,
              item: item,
              nowMs: nowMs,
            );
            if (ok) {
              downloaded++;
              globalRemaining--;
            }
          }
        }
      }
      final next = m['@odata.nextLink'];
      url = next is String && next.isNotEmpty ? next : null;
    }

    if (source.kind == 'photo') {
      await _prunePhotos(ctx, source.category, source.maxFiles);
    } else {
      await _pruneVideos(ctx, source.category, source.maxFiles);
    }

    return downloaded;
  }

  String _childrenListUrl(String graphBase, String path) {
    final encodedPath = _encodeDrivePath(path);
    final base = encodedPath.isEmpty
        ? '$graphBase/me/drive/root/children'
        : '$graphBase/me/drive/root:$encodedPath:/children';
    final uri = Uri.parse(base).replace(
      queryParameters: {
        r'$top': '200',
        r'$orderby': 'lastModifiedDateTime desc',
        r'$select':
            'id,name,size,file,image,video,webUrl,lastModifiedDateTime,createdBy,@microsoft.graph.downloadUrl',
      },
    );
    return uri.toString();
  }

  String _encodeDrivePath(String raw) {
    final trimmed = raw.trim().replaceFirst(RegExp(r'^/+'), '');
    if (trimmed.isEmpty) {
      return '';
    }
    final encoded = trimmed
        .split('/')
        .where((s) => s.isNotEmpty)
        .map(Uri.encodeComponent)
        .join('/');
    return '/$encoded';
  }

  bool _isPhotoMime(String mime) {
    const allowed = {
      'image/jpeg',
      'image/png',
      'image/webp',
      'image/gif',
    };
    return allowed.contains(mime.toLowerCase());
  }

  bool _isVideoMime(String mime) {
    const allowed = {'video/mp4', 'video/quicktime'};
    return allowed.contains(mime.toLowerCase());
  }

  String _displayName(Map<String, dynamic> item) {
    final createdBy = item['createdBy'];
    if (createdBy is Map<String, dynamic>) {
      final user = createdBy['user'];
      if (user is Map<String, dynamic>) {
        final dn = user['displayName'];
        if (dn is String && dn.isNotEmpty) {
          return dn;
        }
      }
    }
    return '';
  }

  int _videoDurationSeconds(Map<String, dynamic> item) {
    final video = item['video'];
    if (video is! Map<String, dynamic>) {
      return 0;
    }
    final d = video['duration'];
    if (d is int) {
      return (d / 1000).round();
    }
    if (d is num) {
      return (d / 1000).round();
    }
    return 0;
  }

  Future<bool> _tryIngestPhoto(
    DataWriteContext ctx, {
    required String rowId,
    required String category,
    required String downloadUrl,
    required Map<String, dynamic> item,
    required int nowMs,
  }) async {
    final exists =
        await (ctx.db.select(
              ctx.db.photos,
            )..where((t) => t.id.equals(rowId)))
            .getSingleOrNull();
    if (exists != null) {
      return false;
    }

    final bytes = await _downloadBytes(downloadUrl);
    if (bytes == null || bytes.isEmpty) {
      return false;
    }

    final name = item['name'];
    final webUrl = item['webUrl'];
    final logicalKey = 'onedrive/photo/$rowId/media';
    final ref = await ctx.blobs.putBytes(bytes, logicalKey: logicalKey);

    final file = item['file'];
    var mime = 'image/jpeg';
    if (file is Map<String, dynamic>) {
      final mt = file['mimeType'];
      if (mt is String && mt.isNotEmpty) {
        mime = mt;
      }
    }

    int? pixelW;
    int? pixelH;
    final image = item['image'];
    if (image is Map<String, dynamic>) {
      pixelW = _positivePixelDimension(image['width']);
      pixelH = _positivePixelDimension(image['height']);
    }

    await ctx.db.into(ctx.db.blobMetadata).insertOnConflictUpdate(
          BlobMetadataCompanion.insert(
            blobKey: logicalKey,
            sha256: ref.storageKey.split('/').last,
            relativePath: ref.storageKey,
            bytes: bytes.length,
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
            dataProvider: Value(kMediaDataProviderOneDrive),
            mediaBlobKey: logicalKey,
            photographerName: _displayName(item),
            photographerUrl: '',
            pexelsPageUrl: webUrl is String ? webUrl : '',
            altText: Value(name is String ? name : ''),
            fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(nowMs),
          ),
        );
    AppDebugLog.provider(
      'onedrive_media: stored photo row=$rowId category=$category bytes=${bytes.length}',
    );
    return true;
  }

  Future<bool> _tryIngestVideo(
    DataWriteContext ctx, {
    required String rowId,
    required String category,
    required String downloadUrl,
    required Map<String, dynamic> item,
    required int nowMs,
  }) async {
    final exists =
        await (ctx.db.select(
              ctx.db.videos,
            )..where((t) => t.id.equals(rowId)))
            .getSingleOrNull();
    if (exists != null) {
      return false;
    }

    final bytes = await _downloadBytes(downloadUrl);
    if (bytes == null || bytes.isEmpty) {
      return false;
    }

    final name = item['name'];
    final webUrl = item['webUrl'];
    final logicalKey = 'onedrive/video/$rowId/media';
    final ref = await ctx.blobs.putBytes(bytes, logicalKey: logicalKey);

    final file = item['file'];
    var mime = 'video/mp4';
    if (file is Map<String, dynamic>) {
      final mt = file['mimeType'];
      if (mt is String && mt.isNotEmpty) {
        mime = mt;
      }
    }

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

    final dur = _videoDurationSeconds(item);

    await ctx.db.into(ctx.db.videos).insert(
          VideosCompanion.insert(
            id: rowId,
            category: Value(category),
            dataProvider: Value(kMediaDataProviderOneDrive),
            mediaBlobKey: logicalKey,
            photographerName: _displayName(item),
            photographerUrl: '',
            pexelsPageUrl: webUrl is String ? webUrl : '',
            altText: Value(name is String ? name : ''),
            durationSeconds: dur < 1 ? 1 : dur,
            fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(nowMs),
          ),
        );
    AppDebugLog.provider(
      'onedrive_media: stored video row=$rowId category=$category bytes=${bytes.length} dur=${dur}s',
    );
    return true;
  }

  Future<List<int>?> _downloadBytes(String url) async {
    try {
      final uri = Uri.parse(url);
      AppDebugLog.provider(
        'onedrive_media: GET file binary ${AppDebugLog.safeHttpUri(uri)}',
      );
      final res = await _http.get(uri);
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
        AppDebugLog.provider(
          'onedrive_media: download status=${res.statusCode} bytes=${res.bodyBytes.length}',
        );
        return null;
      }
      AppDebugLog.provider('onedrive_media: download ok bytes=${res.bodyBytes.length}');
      return res.bodyBytes;
    } on Object catch (e, st) {
      AppDebugLog.providerFail('onedrive_media: download', e, st);
      return null;
    }
  }

  Future<void> _prunePhotos(
    DataWriteContext ctx,
    String category,
    int max,
  ) async {
    if (max < 1) {
      return;
    }
    final rows =
        await (ctx.db.select(
              ctx.db.photos,
            )..where(
                (t) =>
                    t.category.equals(category) &
                    t.dataProvider.equals(kMediaDataProviderOneDrive),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.fetchedAtMs)]))
            .get();
    if (rows.length <= max) {
      return;
    }
    final removeCount = rows.length - max;
    for (var i = 0; i < removeCount; i++) {
      await _deletePhoto(ctx, rows[i]);
    }
  }

  Future<void> _pruneVideos(
    DataWriteContext ctx,
    String category,
    int max,
  ) async {
    if (max < 1) {
      return;
    }
    final rows =
        await (ctx.db.select(
              ctx.db.videos,
            )..where(
                (t) =>
                    t.category.equals(category) &
                    t.dataProvider.equals(kMediaDataProviderOneDrive),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.fetchedAtMs)]))
            .get();
    if (rows.length <= max) {
      return;
    }
    final removeCount = rows.length - max;
    for (var i = 0; i < removeCount; i++) {
      await _deleteVideo(ctx, rows[i]);
    }
  }

  Future<void> _deletePhoto(DataWriteContext ctx, Photo row) async {
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

  Future<void> _deleteVideo(DataWriteContext ctx, Video row) async {
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
}
