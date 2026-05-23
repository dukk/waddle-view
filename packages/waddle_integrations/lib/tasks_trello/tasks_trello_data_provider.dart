import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:waddle_shared/collect/collect_diagnostics.dart';
import 'package:waddle_shared/collect/data_provider.dart';
import 'package:waddle_shared/collect/data_write_context.dart';
import 'package:waddle_shared/integrations/integration_collect.dart';
import 'package:waddle_shared/integrations/integration_kv_repository.dart';
import 'package:waddle_shared/integrations/integration_kv_types.dart';
import 'package:waddle_shared/net/http_debug_uri.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';
import 'package:waddle_shared/secrets/integration_secret_catalog.dart';
import 'package:waddle_shared/tasks/task_sync_upsert.dart';

import 'tasks_trello_provider_extra_config.dart';

const String kTasksTrelloProviderId = 'tasks_trello';
const String kDefaultTrelloApiBaseUrl = 'https://api.trello.com/1';

class TasksTrelloDataProvider implements IDataProvider {
  TasksTrelloDataProvider({
    http.Client? httpClient,
    int Function()? nowMs,
  })  : _http = httpClient ?? http.Client(),
        _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  final http.Client _http;
  final int Function() _nowMs;

  @override
  String get id => kTasksTrelloProviderId;

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
        ctx.diagnostics.provider('tasks_trello: skip poll gate id=$integrationId');
        return;
      }
    }

    final config = await ctx.resolveConfig(integrationId);
    final apiKey = await readTrelloApiKeyForIntegration(ctx.secrets, integrationId);
    final token = config.accessToken;
    if (apiKey == null || apiKey.isEmpty) {
      ctx.diagnostics.provider('tasks_trello: skip (no API key)');
      return;
    }
    if (token == null || token.isEmpty) {
      ctx.diagnostics.provider('tasks_trello: skip (no member token)');
      return;
    }

    final extra = TasksTrelloProviderExtraConfig.parse(config.configJson);
    if (extra.boardIds.isEmpty) {
      ctx.diagnostics.provider('tasks_trello: skip (no boardIds configured)');
      await _markCollected(ctx, integrationId, nowMs);
      return;
    }

    final base = _normalizeBase(config.baseUrl);
    final updatedAt = DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true);
    ctx.diagnostics.provider(
      'tasks_trello: collect boards=${extra.boardIds.length} '
      'base=${safeHttpUriForLog(Uri.parse(base))}',
    );

    for (final boardId in extra.boardIds) {
      try {
        final lists = await _fetchBoardLists(
          diagnostics: ctx.diagnostics,
          base: base,
          apiKey: apiKey,
          token: token,
          boardId: boardId,
          timeoutMs: extra.requestTimeoutMs,
        );
        final snapshots = <TaskListSnapshot>[];
        for (final list in lists) {
          final listId = list['id'] as String? ?? '';
          if (listId.isEmpty) {
            continue;
          }
          final cards = await _fetchListCards(
            diagnostics: ctx.diagnostics,
            base: base,
            apiKey: apiKey,
            token: token,
            listId: listId,
            timeoutMs: extra.requestTimeoutMs,
          );
          snapshots.add(
            TaskListSnapshot(
              externalId: listId,
              label: (list['name'] as String?)?.trim() ?? 'Column',
              columnOrder: _parseTrelloPos(list['pos']),
              tasks: [
                for (final card in cards)
                  TaskSnapshot(
                    externalId: card['id'] as String? ?? '',
                    title: (card['name'] as String?)?.trim() ?? '',
                    description: (card['desc'] as String?)?.trim(),
                    dueAtMs: _parseTrelloDue(card['due']),
                    completed: card['closed'] == true,
                    position: _parseTrelloPos(card['pos']),
                  ),
              ],
            ),
          );
        }
        await syncTaskBoardSnapshot(
          ctx.db,
          integrationType: kTasksTrelloProviderId,
          integrationId: integrationId,
          boardKey: boardId,
          lists: snapshots,
          updatedAt: updatedAt,
        );
        ctx.diagnostics.provider(
          'tasks_trello: synced board=$boardId lists=${snapshots.length}',
        );
      } on Object catch (e, st) {
        ctx.diagnostics.providerFail(
          'tasks_trello: board $boardId failed',
          e,
          st,
        );
      }
    }

    await _markCollected(ctx, integrationId, nowMs);
  }

  String _normalizeBase(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return kDefaultTrelloApiBaseUrl;
    }
    return raw.trim().replaceAll(RegExp(r'/$'), '');
  }

  Future<void> _markCollected(
    DataWriteContext ctx,
    String integrationId,
    int nowMs,
  ) async {
    await IntegrationKvRepository(ctx.db).upsertIntegration(
      integrationId: integrationId,
      key: kIntegrationLastCollectKey,
      value: '$nowMs',
      valueType: kIntegrationKvTypeIntMs,
    );
  }

  Future<List<Map<String, dynamic>>> _fetchBoardLists({
    required CollectDiagnostics diagnostics,
    required String base,
    required String apiKey,
    required String token,
    required String boardId,
    required int timeoutMs,
  }) async {
    final uri = Uri.parse('$base/boards/$boardId/lists').replace(
      queryParameters: {
        'key': apiKey,
        'token': token,
        'fields': 'id,name,pos',
      },
    );
    return _getJsonList(
      diagnostics: diagnostics,
      uri: uri,
      label: 'lists board=$boardId',
      timeoutMs: timeoutMs,
    );
  }

  Future<List<Map<String, dynamic>>> _fetchListCards({
    required CollectDiagnostics diagnostics,
    required String base,
    required String apiKey,
    required String token,
    required String listId,
    required int timeoutMs,
  }) async {
    final uri = Uri.parse('$base/lists/$listId/cards').replace(
      queryParameters: {
        'key': apiKey,
        'token': token,
        'fields': 'id,name,desc,due,closed,pos',
      },
    );
    return _getJsonList(
      diagnostics: diagnostics,
      uri: uri,
      label: 'cards list=$listId',
      timeoutMs: timeoutMs,
    );
  }

  Future<List<Map<String, dynamic>>> _getJsonList({
    required CollectDiagnostics diagnostics,
    required Uri uri,
    required String label,
    required int timeoutMs,
  }) async {
    diagnostics.provider(
      'tasks_trello: GET $label ${safeHttpUriForLog(uri)}',
    );
    final res = await _http
        .get(uri)
        .timeout(Duration(milliseconds: timeoutMs));
    if (res.statusCode != 200) {
      diagnostics.provider(
        'tasks_trello: $label HTTP ${res.statusCode}',
      );
      return const [];
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! List) {
      return const [];
    }
    return [
      for (final entry in decoded)
        if (entry is Map) Map<String, dynamic>.from(entry),
    ];
  }
}

int _parseTrelloPos(Object? raw) {
  if (raw is num) {
    return raw.round();
  }
  if (raw is String) {
    final v = double.tryParse(raw);
    if (v != null) {
      return v.round();
    }
  }
  return 0;
}

DateTime? _parseTrelloDue(Object? raw) {
  if (raw == null) {
    return null;
  }
  final s = raw.toString().trim();
  if (s.isEmpty) {
    return null;
  }
  return DateTime.tryParse(s)?.toUtc();
}
