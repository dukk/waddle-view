import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;

import '../../blob/blob_store.dart';
import '../../config/microsoft_graph_kv.dart';
import '../../debug/app_debug_log.dart';
import '../../persistence/database.dart';
import '../../persistence/tables.dart';
import '../../secrets/secret_store.dart';
import '../data_provider.dart';
import '../data_write_context.dart';
import 'microsoft_graph/microsoft_graph_oauth.dart'
    show MicrosoftGraphOAuth, kMicrosoftGraphAccessTokenSkewMs;
import 'onedrive_media_extra_config.dart';

const String kOneDriveMediaProviderId = 'onedrive_media';

const String kDefaultGraphBaseUrl = 'https://graph.microsoft.com/v1.0';

void _logGraphJsonError(String context, String body) {
  try {
    final j = jsonDecode(body);
    if (j is Map<String, dynamic> && j['error'] is Map<String, dynamic>) {
      final e = j['error'] as Map<String, dynamic>;
      AppDebugLog.engine(
        '$context Graph error code=${e['code']} message=${e['message']}',
      );
      return;
    }
  } on Object {
    // fall through
  }
  final t = body.trim().replaceAll(RegExp(r'\s+'), ' ');
  AppDebugLog.engine(
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
        AppDebugLog.engine(
          'OneDriveMediaDataProvider: poll window bypass (auth needed for '
          '${a.graphAccountKey})',
        );
        return false;
      }
    }

    AppDebugLog.engine(
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
      AppDebugLog.engine(
        'OneDriveMediaDataProvider: skip (no $kMicrosoftGraphClientIdKvKey)',
      );
      return;
    }

    final extra = OneDriveMediaExtraConfig.parse(setting.configJson);
    if (extra.accounts.isEmpty) {
      AppDebugLog.engine(
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
      return;
    }

    final graphBase = _normalizeGraphBase(setting.baseUrl);
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
          AppDebugLog.engine(
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
        await _markCollectDone(ctx.db, nowMs);
      }
    } on Object catch (e, st) {
      AppDebugLog.engineFail('OneDriveMediaDataProvider collect', e, st);
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

    while (url != null && downloaded < perSourceCap && globalRemaining > 0) {
      final pageUrl = url;
      AppDebugLog.engine('OneDriveMediaDataProvider: GET children');
      final res = await _http.get(
        Uri.parse(pageUrl),
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (res.statusCode != 200) {
        AppDebugLog.engine(
          'OneDriveMediaDataProvider: children status=${res.statusCode}',
        );
        _logGraphJsonError('OneDriveMediaDataProvider: children', res.body);
        break;
      }
      final m = jsonDecode(res.body) as Map<String, dynamic>;
      final values = m['value'];
      if (values is List<dynamic>) {
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
    return true;
  }

  Future<List<int>?> _downloadBytes(String url) async {
    try {
      final res = await _http.get(Uri.parse(url));
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
        return null;
      }
      return res.bodyBytes;
    } on Object catch (e, st) {
      AppDebugLog.engineFail('OneDriveMediaDataProvider download', e, st);
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
