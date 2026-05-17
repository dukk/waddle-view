import 'package:waddle_shared/net/http_debug_uri.dart';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;

import 'package:waddle_shared/curation/reject_filter_context.dart';

import 'package:waddle_shared/blob/blob_store.dart';
import 'package:waddle_shared/config/microsoft_graph_kv.dart';
import 'package:waddle_shared/secrets/integration_secret_catalog.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';
import 'package:waddle_shared/secrets/secret_store.dart';
import 'package:waddle_shared/collect/collect_diagnostics.dart';
import 'package:waddle_shared/collect/data_provider.dart';
import 'package:waddle_shared/collect/data_write_context.dart';
import 'package:waddle_shared/integrations/integration_collect.dart';
import '../microsoft_graph/microsoft_graph_base_url.dart';
import '../microsoft_graph/microsoft_graph_oauth.dart'
    show MicrosoftGraphOAuth, kMicrosoftGraphAccessTokenSkewMs;
import 'onedrive_media_extra_config.dart';

const String kVideoOneDriveIntegrationType = 'video_onedrive';

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

void _logGraphJsonError(
  String context,
  String body,
  CollectDiagnostics d,
) {
  try {
    final j = jsonDecode(body);
    if (j is Map<String, dynamic> && j['error'] is Map<String, dynamic>) {
      final e = j['error'] as Map<String, dynamic>;
      d.provider(
        '$context Graph error code=${e['code']} message=${e['message']}',
      );
      return;
    }
  } on Object {
    // fall through
  }
  final t = body.trim().replaceAll(RegExp(r'\s+'), ' ');
  d.provider(
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

/// Per delta page: skip/delete tallies for operator troubleshooting (debug only).
final class _OneDriveDeltaPageStats {
  int badItemId = 0;
  int cloudTombstones = 0;
  int localRowsRemovedForTombstone = 0;
  int notFileFacet = 0;
  int noMime = 0;
  int noDownloadUrl = 0;
  int unsupportedMime = 0;
  int noSpecForMime = 0;
  int skippedExistingPhoto = 0;
  int skippedExistingVideo = 0;
  int downloadFailed = 0;
}

void _logOneDriveDeltaPageStats(
  int page,
  _OneDriveDeltaPageStats s,
  CollectDiagnostics d,
) {
  final parts = <String>[
    if (s.badItemId > 0) 'badId=${s.badItemId}',
    if (s.cloudTombstones > 0) 'tombstones=${s.cloudTombstones}',
    if (s.localRowsRemovedForTombstone > 0)
      'removedLocal=${s.localRowsRemovedForTombstone}',
    if (s.notFileFacet > 0) 'foldersOrNonFiles=${s.notFileFacet}',
    if (s.noMime > 0) 'noMime=${s.noMime}',
    if (s.noDownloadUrl > 0) 'noDownloadUrl=${s.noDownloadUrl}',
    if (s.unsupportedMime > 0) 'unsupportedMime=${s.unsupportedMime}',
    if (s.noSpecForMime > 0) 'noMatchingSourceKind=${s.noSpecForMime}',
    if (s.skippedExistingPhoto > 0) 'skipDupPhoto=${s.skippedExistingPhoto}',
    if (s.skippedExistingVideo > 0) 'skipDupVideo=${s.skippedExistingVideo}',
    if (s.downloadFailed > 0) 'downloadFail=${s.downloadFailed}',
  ];
  if (parts.isEmpty) {
    return;
  }
  d.provider(
    'onedrive_media: delta page=$page tallies ${parts.join(' ')}',
  );
}

/// Syncs photos/videos from OneDrive folders into [Photos] / [Videos] via Graph.
class OneDriveVideosDataProvider implements IDataProvider {
  factory OneDriveVideosDataProvider({
    http.Client? httpClient,
    int Function()? nowMs,
    MicrosoftGraphOAuth? oauth,
  }) {
    final client = httpClient ?? http.Client();
    final clock =
        nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);
    return OneDriveVideosDataProvider._(
      client,
      clock,
      oauth,
    );
  }

  OneDriveVideosDataProvider._(this._http, this._nowMs, this._oauth);

  bool get _ingestPhotos => false;
  bool get _ingestVideos => true;

  final http.Client _http;
  final int Function() _nowMs;
  final MicrosoftGraphOAuth? _oauth;

  @override
  String get id => kVideoOneDriveIntegrationType;

  Future<bool> _shouldSkipForPollWindowOnly(
    AppDatabase db,
    SecretStore secrets,
    String integrationId,
    OneDriveMediaExtraConfig extra,
    int nowMs,
    int pollSeconds,
    CollectDiagnostics diagnostics,
  ) async {
    if (pollSeconds <= 0) {
      return false;
    }
    final lastRow =
        await (db.select(db.configKeyValues)
              ..where(
                (t) => t.key.equals(integrationLastCollectKvKey(integrationId)),
              ))
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
        diagnostics.provider(
          'onedrive_media: poll window bypass (auth needed for '
          '${a.graphAccountKey})',
        );
        return false;
      }
    }

    diagnostics.provider(
      'onedrive_media: skip poll gate lastCollectMs=$last',
    );
    return true;
  }

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

    final clientId =
        await readMicrosoftGraphClientIdFromStore(ctx.secrets) ?? '';
    if (clientId.isEmpty) {
      ctx.diagnostics.provider(
        'onedrive_media: skip (no Microsoft Graph client ID configured)',
      );
      return;
    }

    final extra = OneDriveMediaExtraConfig.parse(setting.configJson);
    if (extra.accounts.isEmpty) {
      ctx.diagnostics.provider(
        'onedrive_media: skip (no accounts in config_json)',
      );
      await _markCollectDone(ctx.db, integrationId, nowMs);
      return;
    }

    if (await _shouldSkipForPollWindowOnly(
          ctx.db,
          ctx.secrets,
          integrationId,
          extra,
          nowMs,
          setting.pollSeconds,
          ctx.diagnostics,
        )) {
      ctx.diagnostics.provider(
        'onedrive_media: skip poll gate pollSeconds=${setting.pollSeconds}',
      );
      return;
    }

    final graphBase = _normalizeGraphBase(setting.baseUrl);
    ctx.diagnostics.provider(
      'onedrive_media: collect graphBase=$graphBase accounts=${extra.accounts.length} '
      'globalLimit=${extra.globalPerPollLimit}',
    );
    for (final a in extra.accounts) {
      final n = a.sources.length;
      if (n > 0) {
        ctx.diagnostics.provider(
          'onedrive_media: config account=${a.graphAccountKey} sources=$n',
        );
      }
    }
    var didSync = false;
    var globalRemaining = extra.globalPerPollLimit;

    try {
      final graphOAuth = _oauth ??
          MicrosoftGraphOAuth(
            httpClient: _http,
            nowMs: _nowMs,
            diagnostics: ctx.diagnostics,
          );
      final groups = _sourcesGroupedByAccountPath(extra);
      final rejectCtx = await RejectFilterContext.loadFromDb(ctx.db);
      for (final account in extra.accounts) {
        if (account.sources.isEmpty) {
          ctx.diagnostics.provider(
            'onedrive_media: skip account=${account.graphAccountKey} (no sources)',
          );
          continue;
        }
        final token = await graphOAuth.ensureAccessToken(
          db: ctx.db,
          secrets: ctx.secrets,
          clientId: clientId,
          graphAccountKey: account.graphAccountKey,
        );
        if (token == null || token.isEmpty) {
          ctx.diagnostics.provider(
            'onedrive_media: no token for ${account.graphAccountKey}',
          );
          continue;
        }

        final byPath = groups[account.graphAccountKey];
        if (byPath == null || byPath.isEmpty) {
          ctx.diagnostics.provider(
            'onedrive_media: skip account=${account.graphAccountKey} '
            '(no paths after grouping)',
          );
          continue;
        }
        ctx.diagnostics.provider(
          'onedrive_media: token ok account=${account.graphAccountKey} '
          'pathGroups=${byPath.length}',
        );
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
            rejectCtx: rejectCtx,
          );
          globalRemaining = outcome.globalRemaining;
          didSync = true;
        }
        if (globalRemaining <= 0) {
          break;
        }
      }
      if (didSync) {
        ctx.diagnostics.provider('onedrive_media: collect ok, last_collect updated');
        await _markCollectDone(ctx.db, integrationId, nowMs);
      } else {
        ctx.diagnostics.provider(
          'onedrive_media: collect finished (no path synced; check tokens, '
          'sources, paths, and Graph errors above)',
        );
      }
    } on Object catch (e, st) {
      ctx.diagnostics.providerFail('onedrive_media: collect', e, st);
    }
  }

  Future<void> _markCollectDone(
    AppDatabase db,
    String integrationId,
    int nowMs,
  ) async {
    await db.into(db.configKeyValues).insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(
            key: integrationLastCollectKvKey(integrationId),
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
    ctx.diagnostics.provider(
      'onedrive_media: GET folder item ${safeHttpUriForLog(uri)}',
    );
    final res = await _http.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (res.statusCode != 200) {
      ctx.diagnostics.provider(
        'onedrive_media: folder item status=${res.statusCode}',
      );
      _logGraphJsonError('onedrive_media: folder item', res.body, ctx.diagnostics);
      return null;
    }
    final m = jsonDecode(res.body) as Map<String, dynamic>;
    if (m['folder'] is! Map<String, dynamic>) {
      ctx.diagnostics.provider(
        'onedrive_media: path is not a folder (missing folder facet)',
      );
      return null;
    }
    final id = m['id'];
    if (id is! String || id.isEmpty) {
      ctx.diagnostics.provider(
        'onedrive_media: folder item JSON missing id '
        '(path="${normalizedPath.isEmpty ? "(drive root)" : normalizedPath}")',
      );
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

  Future<int> _deleteLocalDriveItem(
    DataWriteContext ctx,
    String graphAccountKey,
    String driveItemId,
  ) async {
    final rowId = kOneDriveMediaItemRowId(graphAccountKey, driveItemId);
    var removed = 0;
    final photo =
        await (ctx.db.select(
              ctx.db.photos,
            )..where((t) => t.id.equals(rowId)))
            .getSingleOrNull();
    if (photo != null) {
      await _deletePhoto(ctx, photo);
      removed++;
    }
    final video =
        await (ctx.db.select(
              ctx.db.videos,
            )..where((t) => t.id.equals(rowId)))
            .getSingleOrNull();
    if (video != null) {
      await _deleteVideo(ctx, video);
      removed++;
    }
    return removed;
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
    required RejectFilterContext rejectCtx,
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
          ctx.diagnostics.provider(
            'onedrive_media: sync aborted account=$graphAccountKey '
            'path="${normalizedPath.isEmpty ? '(drive root)' : normalizedPath}" '
            '(folder resolve failed)',
          );
          return (downloads: 0, globalRemaining: globalR);
        }
        url = _folderDeltaUrl(graphBase, folderId);
      }
    }

    final hadStoredDelta = storedRow?.value.trim().isNotEmpty == true;
    ctx.diagnostics.provider(
      'onedrive_media: sync begin account=$graphAccountKey '
      'path="${normalizedPath.isEmpty ? '(drive root)' : normalizedPath}" '
      'specs=${specs.length} resumeDelta=$hadStoredDelta',
    );

    var deltaPage = 0;
    var goneRetries = 0;
    String? deltaLinkToPersist;

    while (url != null && url.isNotEmpty) {
      deltaPage++;
      final pageUri = Uri.parse(url);
      ctx.diagnostics.provider(
        'onedrive_media: GET delta page=$deltaPage '
        '${safeHttpUriForLog(pageUri)}',
      );
      final res = await _http.get(
        pageUri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (res.statusCode == 410) {
        goneRetries++;
        await _clearDeltaKv(ctx.db, deltaKey);
        final loc = res.headers['location']?.trim();
        ctx.diagnostics.provider(
          'onedrive_media: delta 410 Gone page=$deltaPage retry=$goneRetries '
          'locationHeader=${loc != null && loc.isNotEmpty}',
        );
        if (goneRetries > 2) {
          ctx.diagnostics.provider('onedrive_media: delta 410 repeated, abort');
          break;
        }
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
            ctx.diagnostics.provider(
              'onedrive_media: delta 410 folder re-resolve failed for '
              'path="${normalizedPath.isEmpty ? '(drive root)' : normalizedPath}"',
            );
            break;
          }
          url = _folderDeltaUrl(graphBase, folderId);
        }
        continue;
      }
      goneRetries = 0;

      if (res.statusCode != 200) {
        ctx.diagnostics.provider(
          'onedrive_media: delta status=${res.statusCode} page=$deltaPage',
        );
        _logGraphJsonError('onedrive_media: delta', res.body, ctx.diagnostics);
        break;
      }

      final m = jsonDecode(res.body) as Map<String, dynamic>;
      final values = m['value'];
      if (values is List<dynamic>) {
        final pageStats = _OneDriveDeltaPageStats();
        final merged = _deltaItemsLastWins(values);
        ctx.diagnostics.provider(
          'onedrive_media: delta page=$deltaPage uniqueItems=${merged.length}',
        );
        for (final item in merged.values) {
          final id = item['id'];
          if (id is! String || id.isEmpty) {
            pageStats.badItemId++;
            continue;
          }
          if (item['deleted'] is Map<String, dynamic>) {
            pageStats.cloudTombstones++;
            pageStats.localRowsRemovedForTombstone += await _deleteLocalDriveItem(
              ctx,
              graphAccountKey,
              id,
            );
            continue;
          }
          final file = item['file'];
          if (file is! Map<String, dynamic>) {
            pageStats.notFileFacet++;
            continue;
          }
          final mime = file['mimeType'];
          if (mime is! String) {
            pageStats.noMime++;
            continue;
          }
          final dl = item['@microsoft.graph.downloadUrl'];
          if (dl is! String || dl.isEmpty) {
            pageStats.noDownloadUrl++;
            continue;
          }
          final mimeLower = mime.toLowerCase();
          if (!_isPhotoMime(mimeLower) && !_isVideoMime(mimeLower)) {
            pageStats.unsupportedMime++;
            continue;
          }
          final anySpecWantsMime = specs.any((s) => _specMatchesMime(s, mimeLower));
          if (!anySpecWantsMime) {
            pageStats.noSpecForMime++;
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
            if (!_specMatchesMime(spec, mimeLower)) {
              continue;
            }
            var ok = false;
            if (_ingestPhotos && _isPhotoMime(mimeLower)) {
              ok = await _tryIngestPhoto(
                ctx,
                rowId: rowId,
                category: spec.category,
                downloadUrl: dl,
                item: item,
                nowMs: nowMs,
                rejectCtx: rejectCtx,
                pageStats: pageStats,
              );
            } else if (_ingestVideos && _isVideoMime(mimeLower)) {
              ok = await _tryIngestVideo(
                ctx,
                rowId: rowId,
                category: spec.category,
                downloadUrl: dl,
                item: item,
                nowMs: nowMs,
                rejectCtx: rejectCtx,
                pageStats: pageStats,
              );
            }
            if (ok) {
              downloaded++;
              globalR--;
              perSpecLeft[i]--;
            }
          }
        }
        _logOneDriveDeltaPageStats(deltaPage, pageStats, ctx.diagnostics);
      } else {
        ctx.diagnostics.provider(
          'onedrive_media: delta page=$deltaPage missing or invalid value[]',
        );
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
        ctx.diagnostics.provider(
          'onedrive_media: delta page=$deltaPage missing next and delta link',
        );
        break;
      }
    }

    if (deltaLinkToPersist != null && deltaLinkToPersist.isNotEmpty) {
      await _persistDeltaLink(ctx.db, deltaKey, deltaLinkToPersist);
      ctx.diagnostics.provider(
        'onedrive_media: delta checkpoint saved account=$graphAccountKey '
        'path="${normalizedPath.isEmpty ? '(drive root)' : normalizedPath}"',
      );
    }

    for (final s in specs) {
      if (_ingestPhotos && (s.kind == 'photo' || s.kind == 'both')) {
        await _prunePhotos(ctx, s.category, s.maxFiles);
      }
      if (_ingestVideos && (s.kind == 'video' || s.kind == 'both')) {
        await _pruneVideos(ctx, s.category, s.maxFiles);
      }
    }

    ctx.diagnostics.provider(
      'onedrive_media: sync end account=$graphAccountKey '
      'path="${normalizedPath.isEmpty ? '(drive root)' : normalizedPath}" '
      'newDownloads=$downloaded globalRemaining=$globalR',
    );

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
    required RejectFilterContext rejectCtx,
    required _OneDriveDeltaPageStats pageStats,
  }) async {
    final exists =
        await (ctx.db.select(
              ctx.db.photos,
            )..where((t) => t.id.equals(rowId)))
            .getSingleOrNull();
    if (exists != null) {
      pageStats.skippedExistingPhoto++;
      return false;
    }

    final bytes = await _downloadBytes(downloadUrl, diagnostics: ctx.diagnostics);
    if (bytes == null || bytes.isEmpty) {
      pageStats.downloadFailed++;
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

    final photographer = _displayName(item);
    final pageUrl = webUrl is String ? webUrl : '';
    final altText = name is String ? name : '';
    final blocked = rejectCtx.isMediaRejected(
      photographer: photographer,
      altText: altText,
      urls: [pageUrl],
    );

    await ctx.db.into(ctx.db.photos).insert(
          PhotosCompanion.insert(
            id: rowId,
            category: Value(category),
            dataProvider: Value(kMediaDataProviderVideoOneDrive),
            mediaBlobKey: logicalKey,
            photographerName: photographer,
            photographerUrl: '',
            pexelsPageUrl: pageUrl,
            altText: Value(altText),
            fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(nowMs),
            suppressed: Value(blocked),
          ),
        );
    ctx.diagnostics.provider(
      'onedrive_media: stored photo row=$rowId category=$category '
      'bytes=${bytes.length}${blocked ? ' (suppressed by reject list)' : ''}',
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
    required RejectFilterContext rejectCtx,
    required _OneDriveDeltaPageStats pageStats,
  }) async {
    final exists =
        await (ctx.db.select(
              ctx.db.videos,
            )..where((t) => t.id.equals(rowId)))
            .getSingleOrNull();
    if (exists != null) {
      pageStats.skippedExistingVideo++;
      return false;
    }

    final bytes = await _downloadBytes(downloadUrl, diagnostics: ctx.diagnostics);
    if (bytes == null || bytes.isEmpty) {
      pageStats.downloadFailed++;
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
    final photographer = _displayName(item);
    final pageUrl = webUrl is String ? webUrl : '';
    final altText = name is String ? name : '';
    final blocked = rejectCtx.isMediaRejected(
      photographer: photographer,
      altText: altText,
      urls: [pageUrl],
    );

    await ctx.db.into(ctx.db.videos).insert(
          VideosCompanion.insert(
            id: rowId,
            category: Value(category),
            dataProvider: Value(kMediaDataProviderVideoOneDrive),
            mediaBlobKey: logicalKey,
            photographerName: photographer,
            photographerUrl: '',
            pexelsPageUrl: pageUrl,
            altText: Value(altText),
            durationSeconds: dur < 1 ? 1 : dur,
            fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(nowMs),
            suppressed: Value(blocked),
          ),
        );
    ctx.diagnostics.provider(
      'onedrive_media: stored video row=$rowId category=$category '
      'bytes=${bytes.length} dur=${dur}s'
      '${blocked ? ' (suppressed by reject list)' : ''}',
    );
    return true;
  }

  Future<List<int>?> _downloadBytes(
    String url, {
    required CollectDiagnostics diagnostics,
  }) async {
    try {
      final uri = Uri.parse(url);
      diagnostics.provider(
        'onedrive_media: GET file binary ${safeHttpUriForLog(uri)}',
      );
      final res = await _http.get(uri);
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
        diagnostics.provider(
          'onedrive_media: download status=${res.statusCode} bytes=${res.bodyBytes.length}',
        );
        return null;
      }
      diagnostics.provider('onedrive_media: download ok bytes=${res.bodyBytes.length}');
      return res.bodyBytes;
    } on Object catch (e, st) {
      diagnostics.providerFail('onedrive_media: download', e, st);
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
                    t.dataProvider.equals(kMediaDataProviderVideoOneDrive),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.fetchedAtMs)]))
            .get();
    if (rows.length <= max) {
      return;
    }
    final removeCount = rows.length - max;
    ctx.diagnostics.provider(
      'onedrive_media: prune photos category=$category '
      'removed=$removeCount cap=$max (had ${rows.length})',
    );
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
                    t.dataProvider.equals(kMediaDataProviderVideoOneDrive),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.fetchedAtMs)]))
            .get();
    if (rows.length <= max) {
      return;
    }
    final removeCount = rows.length - max;
    ctx.diagnostics.provider(
      'onedrive_media: prune videos category=$category '
      'removed=$removeCount cap=$max (had ${rows.length})',
    );
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
