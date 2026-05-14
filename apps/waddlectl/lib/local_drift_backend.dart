import 'package:drift/drift.dart' show Value;
import 'package:waddle_shared/config/provider_config_resolver.dart';
import 'package:waddle_shared/curation/reject_rescan.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/reject_term_repository.dart';
import 'package:waddle_shared/persistence/tables.dart';
import 'package:waddle_shared/secrets/secret_store.dart';
import 'package:waddle_shared/theme/display_text_scale_kv.dart';
import 'package:waddle_shared/theme/display_theme_ids.dart';
import 'package:waddle_shared/theme/display_theme_kv.dart';

/// Local admin port (Drift + [SecretStore]). A future REST client can implement
/// the same surface for remote operations.
abstract class WaddleAdminBackend {
  AppDatabase get db;
  SecretStore get secrets;

  Future<void> close();

  Future<List<Map<String, Object?>>> listConfig();
  Future<String?> getConfig(String key);
  Future<void> setConfig(String key, String value);
  Future<void> unsetConfig(String key);

  Future<List<Map<String, Object?>>> listScreens();
  Future<Map<String, Object?>?> describeScreen(String id);
  Future<void> updateScreen({
    required String id,
    String? name,
    bool? enabled,
    int? dwellSeconds,
    int? frequencyWeight,
    int? minGapBetweenShowsSeconds,
    String? configJson,
  });

  Future<List<Map<String, Object?>>> listProviders();
  Future<Map<String, Object?>?> describeProvider(String id);
  Future<void> updateProvider({
    required String id,
    bool? enabled,
    int? pollSeconds,
    String? baseUrl,
    String? configJson,
  });
  Future<void> setProviderAccessToken(String providerId, String token);

  Future<List<Map<String, Object?>>> listTickers();
  Future<Map<String, Object?>?> describeTicker(String id);
  Future<void> updateTicker({
    required String id,
    String? name,
    bool? enabled,
    String? tickerType,
    int? frequencyWeight,
    int? sortOrder,
    String? configKey,
  });

  Future<Map<String, Object?>> describeCuratorProgram();
  Future<void> updateCuratorProgram({
    int? programDurationSeconds,
    int? historyDepth,
    String? tickerNewsPixelsPerSecond,
    bool? requireNewsPhotoForScreens,
    String? displayThemeId,
    String? displayTextScaleScreen,
    String? displayTextScaleTicker,
  });

  Future<List<Map<String, Object?>>> listCuratorLimits();
  Future<Map<String, Object?>?> describeCuratorLimit(String dataKey);
  Future<void> updateCuratorLimit({
    required String dataKey,
    int? minPlacementsPerProgram,
    int? maxPlacementsPerProgram,
  });

  Future<String?> describeSecret(String key);
  Future<void> setSecret(String key, String value);
  Future<void> deleteSecret(String key);

  Future<List<Map<String, Object?>>> listRejectTerms();
  Future<String?> getRejectCensorFormat();

  /// Adds or replaces a reject term. Returns the upserted id. Triggers a
  /// background rescan of stored content via [rescanRejectContent].
  Future<String> upsertRejectTerm({
    required String term,
    required String action,
    String? id,
  });
  Future<int> removeRejectTermById(String id);
  Future<int> removeRejectTermByTerm(String term);

  /// Updates the censor format KV entry. The caller is responsible for ensuring
  /// [format] is one of the documented constants.
  Future<void> setRejectCensorFormat(String format);

  Future<Map<String, Object?>> rescanRejectContent();
}

class LocalDriftBackend implements WaddleAdminBackend {
  LocalDriftBackend(this._db, this._secrets);

  final AppDatabase _db;
  final SecretStore _secrets;

  @override
  AppDatabase get db => _db;

  @override
  SecretStore get secrets => _secrets;

  @override
  Future<void> close() => _db.close();

  @override
  Future<List<Map<String, Object?>>> listConfig() async {
    final rows = await _db.select(_db.configKeyValues).get();
    return rows
        .map((e) => <String, Object?>{'key': e.key, 'value': e.value})
        .toList();
  }

  @override
  Future<String?> getConfig(String key) async {
    final row = await (_db.select(
      _db.configKeyValues,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  @override
  Future<void> setConfig(String key, String value) async {
    await _db
        .into(_db.configKeyValues)
        .insertOnConflictUpdate(
          ConfigKeyValuesCompanion.insert(key: key, value: value),
        );
  }

  @override
  Future<void> unsetConfig(String key) async {
    await (_db.delete(
      _db.configKeyValues,
    )..where((t) => t.key.equals(key))).go();
  }

  @override
  Future<List<Map<String, Object?>>> listScreens() async {
    final rows = await _db.select(_db.screenDefinitions).get();
    return rows.map(_screenToMap).toList();
  }

  Map<String, Object?> _screenToMap(ScreenDefinition row) => {
    'id': row.id,
    'name': row.name,
    'description': row.description,
    'enabled': row.enabled,
    'screen_type': row.screenType,
    'config_json': row.configJson,
    'dwell_seconds': row.dwellSeconds,
    'frequency_weight': row.frequencyWeight,
    'min_gap_between_shows_seconds': row.minGapBetweenShowsSeconds,
    'min_placements_per_program': row.minPlacementsPerProgram,
    'max_placements_per_program': row.maxPlacementsPerProgram,
    'data_key': row.dataKey,
  };

  @override
  Future<Map<String, Object?>?> describeScreen(String id) async {
    final row = await (_db.select(
      _db.screenDefinitions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _screenToMap(row);
  }

  @override
  Future<void> updateScreen({
    required String id,
    String? name,
    bool? enabled,
    int? dwellSeconds,
    int? frequencyWeight,
    int? minGapBetweenShowsSeconds,
    String? configJson,
  }) async {
    final existing = await (_db.select(
      _db.screenDefinitions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (existing == null) {
      throw StateError('Unknown screen id: $id');
    }
    await (_db.update(
      _db.screenDefinitions,
    )..where((t) => t.id.equals(id))).write(
      ScreenDefinitionsCompanion(
        name: name == null ? const Value.absent() : Value(name),
        enabled: enabled == null ? const Value.absent() : Value(enabled),
        dwellSeconds: dwellSeconds == null
            ? const Value.absent()
            : Value(dwellSeconds),
        frequencyWeight: frequencyWeight == null
            ? const Value.absent()
            : Value(frequencyWeight),
        minGapBetweenShowsSeconds: minGapBetweenShowsSeconds == null
            ? const Value.absent()
            : Value(minGapBetweenShowsSeconds),
        configJson: configJson == null
            ? const Value.absent()
            : Value(configJson),
      ),
    );
  }

  @override
  Future<List<Map<String, Object?>>> listProviders() async {
    final rows = await _db.select(_db.providerSettings).get();
    return rows.map(_providerToMap).toList();
  }

  Map<String, Object?> _providerToMap(ProviderSetting row) => {
    'id': row.id,
    'provider_type': row.providerType,
    'enabled': row.enabled,
    'poll_seconds': row.pollSeconds,
    'base_url': row.baseUrl,
    'config_json': row.configJson,
  };

  @override
  Future<Map<String, Object?>?> describeProvider(String id) async {
    final row = await (_db.select(
      _db.providerSettings,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _providerToMap(row);
  }

  @override
  Future<void> updateProvider({
    required String id,
    bool? enabled,
    int? pollSeconds,
    String? baseUrl,
    String? configJson,
  }) async {
    final existing = await (_db.select(
      _db.providerSettings,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (existing == null) {
      throw StateError('Unknown provider id: $id');
    }
    await (_db.update(
      _db.providerSettings,
    )..where((t) => t.id.equals(id))).write(
      ProviderSettingsCompanion(
        enabled: enabled == null ? const Value.absent() : Value(enabled),
        pollSeconds: pollSeconds == null
            ? const Value.absent()
            : Value(pollSeconds),
        baseUrl: baseUrl == null
            ? const Value.absent()
            : Value(baseUrl.isEmpty ? null : baseUrl),
        configJson: configJson == null
            ? const Value.absent()
            : Value(configJson.isEmpty ? null : configJson),
      ),
    );
  }

  @override
  Future<void> setProviderAccessToken(String providerId, String token) async {
    await secrets.write(
      '${ProviderConfigResolver.accessTokenKey}:$providerId',
      token,
    );
  }

  @override
  Future<List<Map<String, Object?>>> listTickers() async {
    final rows = await _db.select(_db.tickerDefinitions).get();
    return rows.map(_tickerToMap).toList();
  }

  Map<String, Object?> _tickerToMap(TickerDefinition row) => {
    'id': row.id,
    'name': row.name,
    'description': row.description,
    'enabled': row.enabled,
    'ticker_type': row.tickerType,
    'frequency_weight': row.frequencyWeight,
    'sort_order': row.sortOrder,
    'config_key': row.configKey,
    'config_json_schema': row.configJsonSchema,
    'example_config_json': row.exampleConfigJson,
  };

  @override
  Future<Map<String, Object?>?> describeTicker(String id) async {
    final row = await (_db.select(
      _db.tickerDefinitions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _tickerToMap(row);
  }

  @override
  Future<void> updateTicker({
    required String id,
    String? name,
    bool? enabled,
    String? tickerType,
    int? frequencyWeight,
    int? sortOrder,
    String? configKey,
  }) async {
    final existing = await (_db.select(
      _db.tickerDefinitions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (existing == null) {
      throw StateError('Unknown ticker id: $id');
    }
    await (_db.update(
      _db.tickerDefinitions,
    )..where((t) => t.id.equals(id))).write(
      TickerDefinitionsCompanion(
        name: name == null ? const Value.absent() : Value(name),
        enabled: enabled == null ? const Value.absent() : Value(enabled),
        tickerType: tickerType == null
            ? const Value.absent()
            : Value(tickerType),
        frequencyWeight: frequencyWeight == null
            ? const Value.absent()
            : Value(frequencyWeight),
        sortOrder: sortOrder == null ? const Value.absent() : Value(sortOrder),
        configKey: configKey == null
            ? const Value.absent()
            : Value(configKey.isEmpty ? null : configKey),
      ),
    );
  }

  @override
  Future<Map<String, Object?>> describeCuratorProgram() async {
    Future<String> gv(String k, String d) async => (await getConfig(k)) ?? d;
    return {
      'program_duration_seconds': await gv(
        kCuratorProgramDurationSecondsKvKey,
        '180',
      ),
      'history_depth': await gv(kCuratorHistoryDepthKvKey, '5'),
      'ticker_pixels_per_second': await gv(
        'curator.ticker.newsPixelsPerSecond',
        '',
      ),
      'require_news_photo_for_screens': await gv(
        kRequireNewsPhotoForScreensKvKey,
        'false',
      ),
      'display_theme_id': await gv(
        kDisplayThemeIdKvKey,
        kDefaultDisplayThemeId,
      ),
      'display_text_scale_screen': await gv(
        kDisplayTextScaleScreenKvKey,
        kDisplayTextScaleNormal,
      ),
      'display_text_scale_ticker': await gv(
        kDisplayTextScaleTickerKvKey,
        kDisplayTextScaleNormal,
      ),
    };
  }

  @override
  Future<void> updateCuratorProgram({
    int? programDurationSeconds,
    int? historyDepth,
    String? tickerNewsPixelsPerSecond,
    bool? requireNewsPhotoForScreens,
    String? displayThemeId,
    String? displayTextScaleScreen,
    String? displayTextScaleTicker,
  }) async {
    if (programDurationSeconds != null) {
      await setConfig(
        kCuratorProgramDurationSecondsKvKey,
        '$programDurationSeconds',
      );
    }
    if (historyDepth != null) {
      await setConfig(kCuratorHistoryDepthKvKey, '$historyDepth');
    }
    if (tickerNewsPixelsPerSecond != null) {
      final t = tickerNewsPixelsPerSecond.trim();
      if (t.isNotEmpty) {
        await setConfig('curator.ticker.newsPixelsPerSecond', t);
      }
    }
    if (requireNewsPhotoForScreens != null) {
      await setConfig(
        kRequireNewsPhotoForScreensKvKey,
        requireNewsPhotoForScreens ? 'true' : 'false',
      );
    }
    if (displayThemeId != null) {
      await setConfig(
        kDisplayThemeIdKvKey,
        normalizeDisplayThemeId(displayThemeId),
      );
    }
    if (displayTextScaleScreen != null) {
      await setConfig(
        kDisplayTextScaleScreenKvKey,
        normalizeDisplayTextScaleOption(displayTextScaleScreen),
      );
    }
    if (displayTextScaleTicker != null) {
      await setConfig(
        kDisplayTextScaleTickerKvKey,
        normalizeDisplayTextScaleOption(displayTextScaleTicker),
      );
    }
  }

  @override
  Future<List<Map<String, Object?>>> listCuratorLimits() async {
    final rows = await _db.select(_db.curatorDataKeyProgramLimits).get();
    return rows
        .map(
          (e) => <String, Object?>{
            'data_key': e.dataKey,
            'min_placements_per_program': e.minPlacementsPerProgram,
            'max_placements_per_program': e.maxPlacementsPerProgram,
          },
        )
        .toList();
  }

  @override
  Future<Map<String, Object?>?> describeCuratorLimit(String dataKey) async {
    final row = await (_db.select(
      _db.curatorDataKeyProgramLimits,
    )..where((t) => t.dataKey.equals(dataKey))).getSingleOrNull();
    if (row == null) {
      return null;
    }
    return {
      'data_key': row.dataKey,
      'min_placements_per_program': row.minPlacementsPerProgram,
      'max_placements_per_program': row.maxPlacementsPerProgram,
    };
  }

  @override
  Future<void> updateCuratorLimit({
    required String dataKey,
    int? minPlacementsPerProgram,
    int? maxPlacementsPerProgram,
  }) async {
    await _db
        .into(_db.curatorDataKeyProgramLimits)
        .insertOnConflictUpdate(
          CuratorDataKeyProgramLimitsCompanion(
            dataKey: Value(dataKey),
            minPlacementsPerProgram: minPlacementsPerProgram == null
                ? const Value.absent()
                : Value(minPlacementsPerProgram),
            maxPlacementsPerProgram: maxPlacementsPerProgram == null
                ? const Value.absent()
                : Value(maxPlacementsPerProgram),
          ),
        );
  }

  @override
  Future<String?> describeSecret(String key) => _secrets.read(key);

  @override
  Future<void> setSecret(String key, String value) =>
      _secrets.write(key, value);

  @override
  Future<void> deleteSecret(String key) => _secrets.delete(key);

  @override
  Future<List<Map<String, Object?>>> listRejectTerms() async {
    final repo = RejectTermRepository(_db);
    final rows = await repo.listAll();
    return [
      for (final r in rows)
        <String, Object?>{
          'id': r.id,
          'term': r.term,
          'action': r.action,
          'created_at_ms': r.createdAtMs,
          'updated_at_ms': r.updatedAtMs,
        },
    ];
  }

  @override
  Future<String?> getRejectCensorFormat() async {
    return getConfig(kRejectCensorFormatKvKey);
  }

  @override
  Future<String> upsertRejectTerm({
    required String term,
    required String action,
    String? id,
  }) async {
    final input = RejectTermInput.parse(rawTerm: term, rawAction: action);
    if (input == null) {
      throw ArgumentError(
        'Invalid reject term or action (action must be censor or block).',
      );
    }
    return RejectTermRepository(_db).upsert(input, id: id);
  }

  @override
  Future<int> removeRejectTermById(String id) =>
      RejectTermRepository(_db).deleteById(id);

  @override
  Future<int> removeRejectTermByTerm(String term) =>
      RejectTermRepository(_db).deleteByTerm(term);

  @override
  Future<void> setRejectCensorFormat(String format) async {
    const allowed = {
      kRejectCensorFormatAsterisksFull,
      kRejectCensorFormatAsterisksFixed,
      kRejectCensorFormatFirstLast,
      kRejectCensorFormatBracketedToken,
    };
    if (!allowed.contains(format)) {
      throw ArgumentError(
        'Unknown reject censor format: $format. Allowed: ${allowed.join(', ')}.',
      );
    }
    await setConfig(kRejectCensorFormatKvKey, format);
  }

  @override
  Future<Map<String, Object?>> rescanRejectContent() async {
    final result = await rescanContentForBlockTerms(_db);
    return {
      'rss_articles_marked': result.rssArticlesMarked,
      'jokes_marked': result.jokesMarked,
      'trivia_questions_marked': result.triviaQuestionsMarked,
      'photos_marked': result.photosMarked,
      'videos_marked': result.videosMarked,
      'total_marked': result.totalMarked,
    };
  }
}
