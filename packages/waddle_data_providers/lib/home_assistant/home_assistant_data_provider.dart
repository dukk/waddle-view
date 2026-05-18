import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:http/http.dart' as http;
import 'package:waddle_shared/collect/collect_diagnostics.dart';
import 'package:waddle_shared/collect/data_provider.dart';
import 'package:waddle_shared/collect/data_write_context.dart';
import 'package:waddle_shared/integrations/integration_collect.dart';
import 'package:waddle_shared/net/http_debug_uri.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/runtime/runtime_signal_repository.dart';

import 'home_assistant_provider_extra_config.dart';
import 'home_assistant_state_parser.dart';

const String kHomeAssistantProviderId = 'home_assistant';
const String kDefaultHomeAssistantBaseUrl = 'http://homeassistant.local:8123';

class _ResolvedEntity {
  const _ResolvedEntity({
    required this.id,
    required this.entityId,
  });

  final String id;
  final String entityId;
}

/// Polls Home Assistant REST API for configured entity states.
class HomeAssistantDataProvider implements IDataProvider {
  HomeAssistantDataProvider({
    http.Client? httpClient,
    int Function()? nowMs,
  })  : _http = httpClient ?? http.Client(),
        _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  final http.Client _http;
  final int Function() _nowMs;

  @override
  String get id => kHomeAssistantProviderId;

  @override
  Future<void> collect(DataWriteContext ctx) async {
    final settings = await enabledIntegrationsForType(ctx.db, id);
    if (settings.isEmpty) {
      ctx.diagnostics.provider('home_assistant: skip (disabled)');
      return;
    }
    final setting = settings.first;
    final config = await ctx.resolveConfig(setting.id);
    final token = config.accessToken;
    if (token == null || token.isEmpty) {
      ctx.diagnostics.provider('home_assistant: skip (no access token)');
      return;
    }
    final baseUrl = _normalizeBaseUrl(config.baseUrl);
    if (baseUrl == null) {
      ctx.diagnostics.provider('home_assistant: skip (no base URL)');
      return;
    }
    final extra = HomeAssistantProviderExtraConfig.parse(config.configJson);
    final entities = await _resolveEntities(ctx.db, extra);
    if (entities.isEmpty) {
      ctx.diagnostics.provider('home_assistant: skip (no entities)');
      return;
    }
    final now = _nowMs();
    final signals = RuntimeSignalRepository(ctx.db);
    ctx.diagnostics.provider(
      'home_assistant: collect entities=${entities.length} '
      'base=${safeHttpUriForLog(Uri.parse(baseUrl))}',
    );
    for (final entity in entities) {
      try {
        await _collectOne(
          ctx,
          baseUrl: baseUrl,
          token: token,
          entity: entity,
          timeoutMs: extra.requestTimeoutMs,
          observedAtMs: now,
          signals: signals,
        );
      } on Object catch (e, st) {
        ctx.diagnostics.providerFail(
          'home_assistant: collect entity=${entity.entityId}',
          e,
          st,
        );
      }
    }
  }

  Future<void> _collectOne(
    DataWriteContext ctx, {
    required String baseUrl,
    required String token,
    required _ResolvedEntity entity,
    required int timeoutMs,
    required int observedAtMs,
    required RuntimeSignalRepository signals,
  }) async {
    final encodedId = Uri.encodeComponent(entity.entityId);
    final uri = Uri.parse('$baseUrl/api/states/$encodedId');
    ctx.diagnostics.provider(
      'home_assistant: GET state entity=${entity.entityId} '
      '${safeHttpUriForLog(uri)}',
    );
    final res = await _safeGet(
      uri,
      token: token,
      entityId: entity.entityId,
      timeoutMs: timeoutMs,
      diagnostics: ctx.diagnostics,
    );
    if (res == null) {
      return;
    }
    if (res.statusCode == 404) {
      ctx.diagnostics.provider(
        'home_assistant: state 404 entity=${entity.entityId}',
      );
      return;
    }
    if (res.statusCode != 200) {
      ctx.diagnostics.provider(
        'home_assistant: state status=${res.statusCode} entity=${entity.entityId}',
      );
      return;
    }
    final parsed = parseHomeAssistantStatePayload(res.body);
    if (parsed == null) {
      ctx.diagnostics.provider(
        'home_assistant: invalid payload entity=${entity.entityId}',
      );
      return;
    }
    await ctx.db.into(ctx.db.homeAssistantEntityStates).insertOnConflictUpdate(
          HomeAssistantEntityStatesCompanion.insert(
            entityId: entity.entityId,
            state: parsed.state,
            attributesJson: parsed.attributesJson,
            lastUpdatedMs: Value(parsed.lastUpdatedMs),
            observedAtMs: observedAtMs,
          ),
        );
    ctx.diagnostics.provider(
      'home_assistant: upsert state entity=${entity.entityId} state=${parsed.state}',
    );
    if (entity.entityId.startsWith('binary_sensor.')) {
      await signals.upsert(
        id: entity.entityId,
        value: homeAssistantBinarySensorOn(parsed.state),
        sourcePluginId: kHomeAssistantProviderId,
      );
    }
  }

  Future<List<_ResolvedEntity>> _resolveEntities(
    AppDatabase db,
    HomeAssistantProviderExtraConfig extra,
  ) async {
    final rows = await (db.select(db.interestsHomeAssistantEntities)
          ..where((t) => t.enabled.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
    if (rows.isNotEmpty) {
      return rows
          .take(extra.maxEntitiesPerCollect)
          .map((r) => _ResolvedEntity(id: r.id, entityId: r.entityId))
          .toList();
    }
    final out = <_ResolvedEntity>[];
    for (final entry
        in extra.defaultEntities.take(extra.maxEntitiesPerCollect)) {
      final id = _interestIdForEntity(entry.entityId);
      await db.into(db.interestsHomeAssistantEntities).insertOnConflictUpdate(
            InterestsHomeAssistantEntitiesCompanion.insert(
              id: id,
              entityId: entry.entityId,
              displayName: Value(entry.displayName),
              enabled: const Value(true),
            ),
          );
      out.add(_ResolvedEntity(id: id, entityId: entry.entityId));
    }
    return out;
  }

  String? _normalizeBaseUrl(String? raw) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return kDefaultHomeAssistantBaseUrl;
    }
    return trimmed.replaceAll(RegExp(r'/+$'), '');
  }

  String _interestIdForEntity(String entityId) =>
      entityId.replaceAll('.', '_');

  Future<http.Response?> _safeGet(
    Uri uri, {
    required String token,
    required String entityId,
    required int timeoutMs,
    required CollectDiagnostics diagnostics,
  }) async {
    try {
      return await _http
          .get(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(Duration(milliseconds: timeoutMs));
    } on http.ClientException catch (e, st) {
      diagnostics.providerFail(
        'home_assistant: request failed entity=$entityId',
        e,
        st,
      );
      return null;
    } on SocketException catch (e, st) {
      diagnostics.providerFail(
        'home_assistant: socket failed entity=$entityId',
        e,
        st,
      );
      return null;
    } on Object catch (e, st) {
      diagnostics.providerFail(
        'home_assistant: unexpected error entity=$entityId',
        e,
        st,
      );
      return null;
    }
  }
}
