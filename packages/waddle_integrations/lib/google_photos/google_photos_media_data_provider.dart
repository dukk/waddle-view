import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;

import 'package:waddle_shared/config/google_kv.dart';
import 'package:waddle_shared/blob/blob_store.dart';
import 'package:waddle_shared/collect/data_provider.dart';
import 'package:waddle_shared/collect/data_write_context.dart';
import 'package:waddle_shared/curation/reject_filter_context.dart';
import 'package:waddle_shared/integrations/integration_collect.dart';
import 'package:waddle_shared/integrations/integration_kv_repository.dart';
import 'package:waddle_shared/integrations/integration_kv_types.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';
import 'package:waddle_shared/secrets/integration_secret_catalog.dart';

import '../calendar_google/google_oauth.dart';
import 'google_photos_extra_config.dart';
import 'google_photos_media_download.dart';
import 'google_photos_picker_api.dart';

const String kPhotoGoogleIntegrationType = 'photo_google';
const String kVideoGoogleIntegrationType = 'video_google';

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

/// Downloads Picker-selected Google Photos items into [Photos] or [Videos].
abstract class GooglePhotosMediaDataProvider implements IDataProvider {
  GooglePhotosMediaDataProvider({
    http.Client? httpClient,
    int Function()? nowMs,
    GoogleOAuth? oauth,
    GooglePhotosPickerApi? pickerApi,
  })  : _http = httpClient ?? http.Client(),
        _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch),
        _oauth = oauth,
        _pickerApi = pickerApi;

  bool get ingestPhotos;
  bool get ingestVideos;

  String get dataProviderConstant;

  final http.Client _http;
  final int Function() _nowMs;
  final GoogleOAuth? _oauth;
  final GooglePhotosPickerApi? _pickerApi;

  GoogleOAuth get _oauthClient => _oauth ?? GoogleOAuth(httpClient: _http);
  GooglePhotosPickerApi get _picker =>
      _pickerApi ?? GooglePhotosPickerApi(httpClient: _http);

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
    final kv = IntegrationKvRepository(ctx.db);

    if (setting.pollSeconds > 0) {
      final lastValue =
          await kv.getIntegrationValue(integrationId, kIntegrationLastCollectKey);
      final last = int.tryParse(lastValue ?? '') ?? 0;
      if (nowMs - last < setting.pollSeconds * 1000) {
        ctx.diagnostics.provider(
          'google_photos: skip poll ($integrationId ${setting.pollSeconds}s gate)',
        );
        return;
      }
    }

    final extra = GooglePhotosExtraConfig.parse(setting.configJson);
    if (extra.accounts.isEmpty) {
      ctx.diagnostics.provider('google_photos: no accounts ($integrationId)');
      await kv.upsertIntegration(
        integrationId: integrationId,
        key: kIntegrationLastCollectKey,
        value: '$nowMs',
        valueType: kIntegrationKvTypeIntMs,
      );
      return;
    }

    final clientId = await readGoogleClientIdFromStore(ctx.secrets);
    if (clientId == null || clientId.isEmpty) {
      ctx.diagnostics.provider(
        'google_photos: skip (no Google OAuth client ID) id=$integrationId',
      );
      return;
    }

    var globalRemaining = extra.globalPerPollLimit;
    var anyWork = false;

    try {
      final rejectCtx = await RejectFilterContext.loadFromDb(ctx.db);

      for (final account in extra.accounts) {
        if (globalRemaining <= 0) {
          break;
        }
        final token = await _oauthClient.ensureAccessToken(
          db: ctx.db,
          secrets: ctx.secrets,
          clientId: clientId,
          googleAccountKey: account.googleAccountKey,
          pollDeviceCode: false,
        );
        if (token == null || token.isEmpty) {
          ctx.diagnostics.provider(
            'google_photos: no token for ${account.googleAccountKey}',
          );
          continue;
        }

        for (final source in account.sources) {
          if (globalRemaining <= 0) {
            break;
          }
          if (source.mediaItemIds.isEmpty) {
            continue;
          }
          final sessionId = source.pickerSessionId;
          if (sessionId == null || sessionId.isEmpty) {
            ctx.diagnostics.provider(
              'google_photos: source ${source.sourceId} missing pickerSessionId',
            );
            continue;
          }

          List<GooglePhotosPickedMediaItem> picked;
          try {
            picked = await _picker.listAllMediaItems(
              accessToken: token,
              sessionId: sessionId,
            );
          } on GooglePhotosPickerApiException catch (e) {
            ctx.diagnostics.provider(
              'google_photos: listMediaItems failed session=$sessionId '
              'status=${e.statusCode} (re-pick in controller)',
            );
            continue;
          }

          final byId = {for (final p in picked) p.id: p};
          var perSourceLeft = source.effectivePerPollLimit;

          for (final mediaId in source.mediaItemIds) {
            if (globalRemaining <= 0 || perSourceLeft <= 0) {
              break;
            }
            final item = byId[mediaId];
            if (item == null) {
              continue;
            }
            final ok = await _tryIngest(
              ctx,
              accountKey: account.googleAccountKey,
              source: source,
              item: item,
              accessToken: token,
              nowMs: nowMs,
              rejectCtx: rejectCtx,
            );
            if (ok) {
              anyWork = true;
              globalRemaining--;
              perSourceLeft--;
            }
          }

          await _pruneCategory(ctx, source.category, source.maxFiles);
        }
      }

      await kv.upsertIntegration(
        integrationId: integrationId,
        key: kIntegrationLastCollectKey,
        value: '$nowMs',
        valueType: kIntegrationKvTypeIntMs,
      );
      if (anyWork) {
        ctx.diagnostics.provider('google_photos: collect ok id=$integrationId');
      }
    } on Object catch (e, st) {
      ctx.diagnostics.providerFail('google_photos: collect', e, st);
    }
  }

  Future<bool> _tryIngest(
    DataWriteContext ctx, {
    required String accountKey,
    required GooglePhotosSourceSpec source,
    required GooglePhotosPickedMediaItem item,
    required String accessToken,
    required int nowMs,
    required RejectFilterContext rejectCtx,
  }) async {
    if (ingestPhotos && item.isPhoto) {
      return _tryIngestPhoto(
        ctx,
        accountKey: accountKey,
        category: source.category,
        item: item,
        accessToken: accessToken,
        nowMs: nowMs,
        rejectCtx: rejectCtx,
      );
    }
    if (ingestVideos && item.isVideo) {
      if (item.videoProcessingStatus != null &&
          item.videoProcessingStatus != 'READY') {
        ctx.diagnostics.provider(
          'google_photos: skip video ${item.id} status=${item.videoProcessingStatus}',
        );
        return false;
      }
      return _tryIngestVideo(
        ctx,
        accountKey: accountKey,
        category: source.category,
        item: item,
        accessToken: accessToken,
        nowMs: nowMs,
        rejectCtx: rejectCtx,
      );
    }
    return false;
  }

  Future<bool> _tryIngestPhoto(
    DataWriteContext ctx, {
    required String accountKey,
    required String category,
    required GooglePhotosPickedMediaItem item,
    required String accessToken,
    required int nowMs,
    required RejectFilterContext rejectCtx,
  }) async {
    final rowId = googlePhotosPhotoRowId(accountKey, item.id);
    final exists = await (ctx.db.select(ctx.db.photos)
          ..where((t) => t.id.equals(rowId)))
        .getSingleOrNull();
    if (exists != null) {
      return false;
    }

    final url = googlePhotosPhotoDownloadUrl(item.baseUrl);
    final bytes = await downloadGooglePhotosBytes(
      client: _http,
      downloadUrl: url,
      accessToken: accessToken,
    );
    if (bytes == null || bytes.isEmpty) {
      return false;
    }

    final logicalKey = 'google_photos/photo/$rowId/media';
    final ref = await ctx.blobs.putBytes(bytes, logicalKey: logicalKey);
    final pw = _positivePixelDimension(item.width);
    final ph = _positivePixelDimension(item.height);

    await ctx.db.into(ctx.db.blobMetadata).insertOnConflictUpdate(
          BlobMetadataCompanion.insert(
            blobKey: logicalKey,
            sha256: ref.storageKey.split('/').last,
            relativePath: ref.storageKey,
            bytes: bytes.length,
            mimeType: Value(item.mimeType),
            capturedAt: DateTime.fromMillisecondsSinceEpoch(nowMs),
            pixelWidth: pw != null ? Value(pw) : const Value.absent(),
            pixelHeight: ph != null ? Value(ph) : const Value.absent(),
          ),
        );

    final altText = item.filename;
    final blocked = rejectCtx.isMediaRejected(
      photographer: '',
      altText: altText,
      urls: const [],
    );

    await ctx.db.into(ctx.db.photos).insert(
          PhotosCompanion.insert(
            id: rowId,
            category: Value(category),
            dataProvider: Value(dataProviderConstant),
            mediaBlobKey: logicalKey,
            photographerName: '',
            photographerUrl: '',
            pageUrl: '',
            altText: Value(altText),
            fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(nowMs),
            suppressed: Value(blocked),
          ),
        );
    ctx.diagnostics.provider(
      'google_photos: stored photo row=$rowId category=$category',
    );
    return true;
  }

  Future<bool> _tryIngestVideo(
    DataWriteContext ctx, {
    required String accountKey,
    required String category,
    required GooglePhotosPickedMediaItem item,
    required String accessToken,
    required int nowMs,
    required RejectFilterContext rejectCtx,
  }) async {
    final rowId = googlePhotosVideoRowId(accountKey, item.id);
    final exists = await (ctx.db.select(ctx.db.videos)
          ..where((t) => t.id.equals(rowId)))
        .getSingleOrNull();
    if (exists != null) {
      return false;
    }

    final url = googlePhotosVideoDownloadUrl(item.baseUrl);
    final bytes = await downloadGooglePhotosBytes(
      client: _http,
      downloadUrl: url,
      accessToken: accessToken,
    );
    if (bytes == null || bytes.isEmpty) {
      return false;
    }

    final logicalKey = 'google_photos/video/$rowId/media';
    final ref = await ctx.blobs.putBytes(bytes, logicalKey: logicalKey);

    await ctx.db.into(ctx.db.blobMetadata).insertOnConflictUpdate(
          BlobMetadataCompanion.insert(
            blobKey: logicalKey,
            sha256: ref.storageKey.split('/').last,
            relativePath: ref.storageKey,
            bytes: bytes.length,
            mimeType: Value(item.mimeType),
            capturedAt: DateTime.fromMillisecondsSinceEpoch(nowMs),
          ),
        );

    final altText = item.filename;
    final blocked = rejectCtx.isMediaRejected(
      photographer: '',
      altText: altText,
      urls: const [],
    );

    await ctx.db.into(ctx.db.videos).insert(
          VideosCompanion.insert(
            id: rowId,
            category: Value(category),
            dataProvider: Value(dataProviderConstant),
            mediaBlobKey: logicalKey,
            photographerName: '',
            photographerUrl: '',
            pexelsPageUrl: '',
            altText: Value(altText),
            durationSeconds: 1,
            fetchedAtMs: DateTime.fromMillisecondsSinceEpoch(nowMs),
            suppressed: Value(blocked),
          ),
        );
    ctx.diagnostics.provider(
      'google_photos: stored video row=$rowId category=$category',
    );
    return true;
  }

  Future<void> _pruneCategory(
    DataWriteContext ctx,
    String category,
    int maxFiles,
  ) async {
    if (maxFiles < 1) {
      return;
    }
    if (ingestPhotos) {
      await _prunePhotos(ctx, category, maxFiles);
    }
    if (ingestVideos) {
      await _pruneVideos(ctx, category, maxFiles);
    }
  }

  Future<void> _prunePhotos(
    DataWriteContext ctx,
    String category,
    int max,
  ) async {
    final rows = await (ctx.db.select(ctx.db.photos)
          ..where((t) => t.category.equals(category))
          ..where((t) => t.dataProvider.equals(dataProviderConstant))
          ..orderBy([(t) => OrderingTerm.asc(t.fetchedAtMs)]))
        .get();
    if (rows.length <= max) {
      return;
    }
    final toRemove = rows.length - max;
    for (var i = 0; i < toRemove; i++) {
      final row = rows[i];
      final key = row.mediaBlobKey;
      if (key.isNotEmpty) {
        final meta = await (ctx.db.select(ctx.db.blobMetadata)
              ..where((t) => t.blobKey.equals(key)))
            .getSingleOrNull();
        await (ctx.db.delete(ctx.db.blobMetadata)
              ..where((t) => t.blobKey.equals(key)))
            .go();
        if (meta != null) {
          await ctx.blobs.delete(BlobRef(meta.relativePath));
        }
      }
      await (ctx.db.delete(ctx.db.photos)..where((t) => t.id.equals(row.id)))
          .go();
    }
  }

  Future<void> _pruneVideos(
    DataWriteContext ctx,
    String category,
    int max,
  ) async {
    final rows = await (ctx.db.select(ctx.db.videos)
          ..where((t) => t.category.equals(category))
          ..where((t) => t.dataProvider.equals(dataProviderConstant))
          ..orderBy([(t) => OrderingTerm.asc(t.fetchedAtMs)]))
        .get();
    if (rows.length <= max) {
      return;
    }
    final toRemove = rows.length - max;
    for (var i = 0; i < toRemove; i++) {
      final row = rows[i];
      final key = row.mediaBlobKey;
      if (key.isNotEmpty) {
        final meta = await (ctx.db.select(ctx.db.blobMetadata)
              ..where((t) => t.blobKey.equals(key)))
            .getSingleOrNull();
        await (ctx.db.delete(ctx.db.blobMetadata)
              ..where((t) => t.blobKey.equals(key)))
            .go();
        if (meta != null) {
          await ctx.blobs.delete(BlobRef(meta.relativePath));
        }
      }
      await (ctx.db.delete(ctx.db.videos)..where((t) => t.id.equals(row.id)))
          .go();
    }
  }
}

class GooglePhotosPhotosDataProvider extends GooglePhotosMediaDataProvider {
  GooglePhotosPhotosDataProvider({
    super.httpClient,
    super.nowMs,
    super.oauth,
    super.pickerApi,
  });

  @override
  String get id => kPhotoGoogleIntegrationType;

  @override
  bool get ingestPhotos => true;

  @override
  bool get ingestVideos => false;

  @override
  String get dataProviderConstant => kMediaDataProviderPhotoGoogle;
}

class GooglePhotosVideosDataProvider extends GooglePhotosMediaDataProvider {
  GooglePhotosVideosDataProvider({
    super.httpClient,
    super.nowMs,
    super.oauth,
    super.pickerApi,
  });

  @override
  String get id => kVideoGoogleIntegrationType;

  @override
  bool get ingestPhotos => false;

  @override
  bool get ingestVideos => true;

  @override
  String get dataProviderConstant => kMediaDataProviderVideoGoogle;
}
