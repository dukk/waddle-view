import 'package:drift/drift.dart' show Value;
import 'package:waddle_shared/curation/reject_rescan.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/reject_term_repository.dart';
import 'package:waddle_shared/persistence/tables.dart';
import 'package:waddle_shared/theme/display_text_scale_kv.dart';
import 'package:waddle_shared/theme/display_theme_ids.dart';
import 'package:waddle_shared/theme/display_theme_kv.dart';

/// Local admin port (Drift). A future REST client can implement the same
/// surface for remote operations.
abstract class WaddleAdminBackend {
  AppDatabase get db;

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
    int? minDwellSeconds,
    int? maxDwellSeconds,
    int? frequencyWeight,
    int? minGapBetweenShowsSeconds,
    String? configJson,
  });

  Future<List<Map<String, Object?>>> listIntegrations();
  Future<Map<String, Object?>?> describeIntegration(String id);
  Future<void> updateIntegration({
    required String id,
    bool? enabled,
    int? pollSeconds,
    String? baseUrl,
    String? configJson,
  });

  Future<List<Map<String, Object?>>> listTickers();
  Future<Map<String, Object?>?> describeTicker(String id);
  Future<void> updateTicker({
    required String id,
    String? name,
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
  LocalDriftBackend(this._db);

  final AppDatabase _db;

  @override
  AppDatabase get db => _db;

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
    final rows = await _db.select(_db.screens).get();
    return rows.map(_screenToMap).toList();
  }

  Map<String, Object?> _screenToMap(ScreenDefinition row) => {
    'id': row.id,
    'name': row.name,
    'description': row.description,
    'screen_type': row.screenType,
    'config_json': row.configJson,
    'min_dwell_seconds': row.minDwellSeconds,
    'max_dwell_seconds': row.maxDwellSeconds,
    'frequency_weight': row.frequencyWeight,
    'min_gap_between_shows_seconds': row.minGapBetweenShowsSeconds,
    'min_placements_per_program': row.minPlacementsPerProgram,
    'max_placements_per_program': row.maxPlacementsPerProgram,
    'data_key': row.dataKey,
  };

  @override
  Future<Map<String, Object?>?> describeScreen(String id) async {
    final row = await (_db.select(
      _db.screens,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _screenToMap(row);
  }

  @override
  Future<void> updateScreen({
    required String id,
    String? name,
    int? minDwellSeconds,
    int? maxDwellSeconds,
    int? frequencyWeight,
    int? minGapBetweenShowsSeconds,
    String? configJson,
  }) async {
    final existing = await (_db.select(
      _db.screens,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (existing == null) {
      throw StateError('Unknown screen id: $id');
    }
    await (_db.update(
      _db.screens,
    )..where((t) => t.id.equals(id))).write(
      ScreensCompanion(
        name: name == null ? const Value.absent() : Value(name),
        minDwellSeconds: minDwellSeconds == null
            ? const Value.absent()
            : Value(minDwellSeconds),
        maxDwellSeconds: maxDwellSeconds == null
            ? const Value.absent()
            : Value(maxDwellSeconds),
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
  Future<List<Map<String, Object?>>> listIntegrations() async {
    final rows = await _db.select(_db.integrations).get();
    return rows.map(_integrationToMap).toList();
  }

  Map<String, Object?> _integrationToMap(Integration row) => {
    'id': row.id,
    'integration_type': row.providerType,
    'enabled': row.enabled,
    'poll_seconds': row.pollSeconds,
    'base_url': row.baseUrl,
    'config_json': row.configJson,
  };

  @override
  Future<Map<String, Object?>?> describeIntegration(String id) async {
    final row = await (_db.select(
      _db.integrations,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _integrationToMap(row);
  }

  @override
  Future<void> updateIntegration({
    required String id,
    bool? enabled,
    int? pollSeconds,
    String? baseUrl,
    String? configJson,
  }) async {
    final existing = await (_db.select(
      _db.integrations,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (existing == null) {
      throw StateError('Unknown integration id: $id');
    }
    await (_db.update(
      _db.integrations,
    )..where((t) => t.id.equals(id))).write(
      IntegrationsCompanion(
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
  Future<List<Map<String, Object?>>> listTickers() async {
    final rows = await _db.select(_db.tickerTapes).get();
    return rows.map(_tickerToMap).toList();
  }

  Map<String, Object?> _tickerToMap(TickerTape row) => {
    'id': row.id,
    'name': row.name,
    'description': row.description,
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
      _db.tickerTapes,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _tickerToMap(row);
  }

  @override
  Future<void> updateTicker({
    required String id,
    String? name,
    String? tickerType,
    int? frequencyWeight,
    int? sortOrder,
    String? configKey,
  }) async {
    final existing = await (_db.select(
      _db.tickerTapes,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (existing == null) {
      throw StateError('Unknown ticker id: $id');
    }
    await (_db.update(
      _db.tickerTapes,
    )..where((t) => t.id.equals(id))).write(
      TickerTapesCompanion(
        name: name == null ? const Value.absent() : Value(name),
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

  Future<CuratorConfiguration?> _defaultCuratorConfiguration() async {
    final defaults = await (_db.select(_db.curatorConfigurations)
          ..where((t) => t.defaultConfig.equals(true)))
        .get();
    if (defaults.isNotEmpty) {
      return defaults.first;
    }
    return (_db.select(_db.curatorConfigurations)..limit(1))
        .getSingleOrNull();
  }

  @override
  Future<Map<String, Object?>> describeCuratorProgram() async {
    Future<String> gv(String k, String d) async => (await getConfig(k)) ?? d;
    final config = await _defaultCuratorConfiguration();
    return {
      if (config != null) 'default_configuration_id': config.id,
      'program_duration_seconds': config?.programDurationSeconds ?? 180,
      'history_depth': config?.historyDepth ?? 5,
      'require_news_photo_for_screens':
          config?.requireNewsPhotoForScreens ?? true,
      'theme_id_override': config?.themeIdOverride,
      'ticker_pixels_per_second': await gv(
        'curator.ticker.newsPixelsPerSecond',
        '',
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
    final config = await _defaultCuratorConfiguration();
    if (config != null &&
        (programDurationSeconds != null ||
            historyDepth != null ||
            requireNewsPhotoForScreens != null)) {
      await (_db.update(_db.curatorConfigurations)
            ..where((t) => t.id.equals(config.id)))
          .write(
        CuratorConfigurationsCompanion(
          programDurationSeconds: programDurationSeconds == null
              ? const Value.absent()
              : Value(programDurationSeconds),
          historyDepth: historyDepth == null
              ? const Value.absent()
              : Value(historyDepth),
          requireNewsPhotoForScreens: requireNewsPhotoForScreens == null
              ? const Value.absent()
              : Value(requireNewsPhotoForScreens),
        ),
      );
    }
    if (tickerNewsPixelsPerSecond != null) {
      final t = tickerNewsPixelsPerSecond.trim();
      if (t.isNotEmpty) {
        await setConfig('curator.ticker.newsPixelsPerSecond', t);
      }
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
