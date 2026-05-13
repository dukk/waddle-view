import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;

import '../../../blob/blob_store.dart';
import '../../../config/microsoft_graph_kv.dart';
import '../../../debug/app_debug_log.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';
import 'package:waddle_shared/secrets/secret_store.dart';
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

const String _onedriveDeltaSelect =
    'id,name,size,file,image,video,webUrl,lastModifiedDateTime,createdBy,@microsoft.graph.downloadUrl,folder';

Map<String, String> _onedriveDeltaQueryParams() => {
      r'$top': '200',
      r'$select': _onedriveDeltaSelect,
    };

Map<String, Map<String, dynamic>> _deltaItemsLastWins(List<dynamic> values) {
  final byId = <String, Map<String, dynamic>>{};
  for (final raw in values) {
    if (raw is Map<String, dynamic>) {
      final id = raw['id'];
      if (id is String && id.isNotEmpty) {
        byId[id] = Map<String, dynamic>.from(raw);
      }
    }
  }
  return byId;
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
      final groups = _sourcesGroupedByAccountPath(extra);
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

        final byPath = groups[account.graphAccountKey];
        if (byPath == null || byPath.isEmpty) {
          continue;
        }
        for (final entry in byPath.entries) {
          if (globalRemaining <= 0) {
            break;
          }
          final outcome = await _syncPathGroup(
            ctx,
            graphBase: graphBase,
            accessToken: token,
            graphAccountKey: account.graphAccountKey,
            normalizedPath: entry.key,
            specs: entry.value,
            nowMs: nowMs,
            globalRemaining: globalRemaining,
          );
          globalRemaining = outcome.globalRemaining;
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

  Map<String, Map<String, List<OneDriveMediaSourceSpec>>>
      _sourcesGroupedByAccountPath(OneDriveMediaExtraConfig extra) {
    final out = <String, Map<String, List<OneDriveMediaSourceSpec>>>{};
    for (final account in extra.accounts) {
      final byPath = out.putIfAbsent(account.graphAccountKey, () => {});
      for (final source in account.sources) {
        final key = _normalizePathKey(source.path);
        byPath.putIfAbsent(key, () => []).add(source);
      }
    }
    return out;
  }

  String _normalizePathKey(String raw) {
    return raw.trim().replaceFirst(RegExp(r'^/+'), '');
  }

  String _rootDeltaUrl(String graphBase) {
    return Uri.parse('$graphBase/me/drive/root/delta')
        .replace(queryParameters: _onedriveDeltaQueryParams())
        .toString();
  }

  String _folderDeltaUrl(String graphBase, String folderId) {
    return Uri.parse('$graphBase/me/drive/items/$folderId/delta')
        .replace(queryParameters: _onedriveDeltaQueryParams())
        .toString();
  }

  Future<void> _clearDeltaKv(AppDatabase db, String deltaKey) async {
    await (db.delete(
      db.configKeyValues,
    )..where((t) => t.key.equals(deltaKey))).go();
  }

  Future<void> _persistDeltaLink(
    AppDatabase db,
    String deltaKey,
    String deltaLink,
  ) async {
    await db.into(db.configKeyValues).insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: deltaKey,
            value: deltaLink,
          ),
        );
  }

  Future<String?> _resolveFolderId(
    DataWriteContext ctx, {
    required String graphBase,
    required String accessToken,
    required String normalizedPath,
  }) async {
    final encodedPath = _encodeDrivePath(normalizedPath);
    final itemUrl = encodedPath.isEmpty
        ? '$graphBase/me/drive/root'
        : '$graphBase/me/drive/root:$encodedPath:';
    final uri = Uri.parse(itemUrl).replace(
      queryParameters: const {
        r'$select': 'id,folder',
      },
    );
    AppDebugLog.provider(
      'onedrive_media: GET folder item ${AppDebugLog.safeHttpUri(uri)}',
    );
    final res = await _http.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (res.statusCode != 200) {
      AppDebugLog.provider(
        'onedrive_media: folder item status=${res.statusCode}',
      );
      _logGraphJsonError('onedrive_media: folder item', res.body);
      return null;
    }
    final m = jsonDecode(res.body) as Map<String, dynamic>;
    if (m['folder'] is! Map<String, dynamic>) {
      AppDebugLog.provider(
        'onedrive_media: path is not a folder (missing folder facet)',
      );
      return null;
    }
    final id = m['id'];
    if (id is! String || id.isEmpty) {
      return null;
    }
    return id;
  }

  bool _specMatchesMime(OneDriveMediaSourceSpec spec, String mime) {
    switch (spec.kind) {
      case 'photo':
        return _isPhotoMime(mime);
      case 'video':
        return _isVideoMime(mime);
      case 'both':
        return _isPhotoMime(mime) || _isVideoMime(mime);
      default:
        return false;
    }
  }

  Future<void> _deleteLocalDriveItem(
    DataWriteContext ctx,
    String graphAccountKey,
    String driveItemId,
  ) async {
    final rowId = kOneDriveMediaItemRowId(graphAccountKey, driveItemId);
    final photo =
        await (ctx.db.select(
              ctx.db.photos,
            )..where((t) => t.id.equals(rowId)))
            .getSingleOrNull();
    if (photo != null) {
      await _deletePhoto(ctx, photo);
    }
    final video =
        await (ctx.db.select(
              ctx.db.videos,
            )..where((t) => t.id.equals(rowId)))
            .getSingleOrNull();
    if (video != null) {
      await _deleteVideo(ctx, video);
    }
  }

  /// Pull-only delta sync for one account path (recursive subtree). Returns
  /// updated [globalRemaining] after downloads.
  Future<({int downloads, int globalRemaining})> _syncPathGroup(
    DataWriteContext ctx, {
    required String graphBase,
    required String accessToken,
    required String graphAccountKey,
    required String normalizedPath,
    required List<OneDriveMediaSourceSpec> specs,
    required int nowMs,
    required int globalRemaining,
  }) async {
    final deltaKey = kOneDriveMediaDeltaLinkKvKey(
      graphAccountKey,
      normalizedPath,
    );
    final storedRow =
        await (ctx.db.select(
              ctx.db.configKeyValues,
            )..where((t) => t.key.equals(deltaKey)))
            .getSingleOrNull();
    var url = storedRow?.value.trim();
    var downloaded = 0;
    var globalR = globalRemaining;
    final perSpecLeft = specs.map((s) => s.effectivePerPollLimit).toList();

    if (url == null || url.isEmpty) {
      if (normalizedPath.isEmpty) {
        url = _rootDeltaUrl(graphBase);
      } else {
        final folderId = await _resolveFolderId(
          ctx,
          graphBase: graphBase,
          accessToken: accessToken,
          normalizedPath: normalizedPath,
        );
        if (folderId == null) {
          return (downloads: 0, globalRemaining: globalR);
        }
        url = _folderDeltaUrl(graphBase, folderId);
      }
    }

    var deltaPage = 0;
    var goneRetries = 0;
    String? deltaLinkToPersist;

    while (url != null && url.isNotEmpty) {
      deltaPage++;
      final pageUri = Uri.parse(url);
      AppDebugLog.provider(
        'onedrive_media: GET delta page=$deltaPage '
        '${AppDebugLog.safeHttpUri(pageUri)}',
      );
      final res = await _http.get(
        pageUri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (res.statusCode == 410) {
        goneRetries++;
        if (goneRetries > 2) {
          AppDebugLog.provider('onedrive_media: delta 410 repeated, abort');
          break;
        }
        await _clearDeltaKv(ctx.db, deltaKey);
        final loc = res.headers['location']?.trim();
        if (loc != null && loc.isNotEmpty) {
          url = loc;
        } else if (normalizedPath.isEmpty) {
          url = _rootDeltaUrl(graphBase);
        } else {
          final folderId = await _resolveFolderId(
            ctx,
            graphBase: graphBase,
            accessToken: accessToken,
            normalizedPath: normalizedPath,
          );
          if (folderId == null) {
            break;
          }
          url = _folderDeltaUrl(graphBase, folderId);
        }
        continue;
      }
      goneRetries = 0;

      if (res.statusCode != 200) {
        AppDebugLog.provider(
          'onedrive_media: delta status=${res.statusCode} page=$deltaPage',
        );
        _logGraphJsonError('onedrive_media: delta', res.body);
        break;
      }

      final m = jsonDecode(res.body) as Map<String, dynamic>;
      final values = m['value'];
      if (values is List<dynamic>) {
        final merged = _deltaItemsLastWins(values);
        AppDebugLog.provider(
          'onedrive_media: delta page=$deltaPage uniqueItems=${merged.length}',
        );
        for (final item in merged.values) {
          final id = item['id'];
          if (id is! String || id.isEmpty) {
            continue;
          }
          if (item['deleted'] is Map<String, dynamic>) {
            await _deleteLocalDriveItem(ctx, graphAccountKey, id);
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
          final dl = item['@microsoft.graph.downloadUrl'];
          if (dl is! String || dl.isEmpty) {
            continue;
          }
          final rowId = kOneDriveMediaItemRowId(graphAccountKey, id);

          for (var i = 0; i < specs.length; i++) {
            if (globalR <= 0) {
              break;
            }
            if (perSpecLeft[i] <= 0) {
              continue;
            }
            final spec = specs[i];
            if (!_specMatchesMime(spec, mime)) {
              continue;
            }
            var ok = false;
            if (_isPhotoMime(mime)) {
              ok = await _tryIngestPhoto(
                ctx,
                rowId: rowId,
                category: spec.category,
                downloadUrl: dl,
                item: item,
                nowMs: nowMs,
              );
            } else if (_isVideoMime(mime)) {
              ok = await _tryIngestVideo(
                ctx,
                rowId: rowId,
                category: spec.category,
                downloadUrl: dl,
                item: item,
                nowMs: nowMs,
              );
            }
            if (ok) {
              downloaded++;
              globalR--;
              perSpecLeft[i]--;
            }
          }
        }
      }

      final nextLink = m['@odata.nextLink'];
      final dLink = m['@odata.deltaLink'];
      if (dLink is String && dLink.isNotEmpty) {
        deltaLinkToPersist = dLink;
        break;
      }
      if (nextLink is String && nextLink.isNotEmpty) {
        url = nextLink;
      } else {
        AppDebugLog.provider(
          'onedrive_media: delta page=$deltaPage missing next and delta link',
        );
        break;
      }
    }

    if (deltaLinkToPersist != null && deltaLinkToPersist.isNotEmpty) {
      await _persistDeltaLink(ctx.db, deltaKey, deltaLinkToPersist);
    }

    for (final s in specs) {
      if (s.kind == 'photo' || s.kind == 'both') {
        await _prunePhotos(ctx, s.category, s.maxFiles);
      }
      if (s.kind == 'video' || s.kind == 'both') {
        await _pruneVideos(ctx, s.category, s.maxFiles);
      }
    }

    return (downloads: downloaded, globalRemaining: globalR);
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
