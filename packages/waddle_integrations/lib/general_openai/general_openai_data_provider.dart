import 'package:waddle_shared/net/http_debug_uri.dart';
import 'dart:convert';

import 'package:waddle_shared/collect/data_provider.dart';
import 'package:waddle_shared/collect/data_write_context.dart';
import 'package:waddle_shared/config/provider_runtime_config.dart';
import 'package:waddle_shared/integrations/integration_collect.dart';
import 'package:waddle_shared/integrations/integration_kv_types.dart';
import 'package:waddle_shared/persistence/database.dart';

import '../openai/openai_api_base_url.dart';
import 'general_openai_config.dart';
import 'general_openai_kv_store.dart';
import 'general_openai_mcp_tools.dart';
import 'openai_responses_client.dart';

export 'general_openai_config.dart' show kGeneralOpenAiProviderId;

/// Runs configured OpenAI prompts on a schedule; stores results in integration KV.
class GeneralOpenAiDataProvider implements IDataProvider {
  GeneralOpenAiDataProvider({
    OpenAiResponsesClient? responsesClient,
    DateTime Function()? now,
  })  : _responses = responsesClient ?? OpenAiResponsesClient(),
        _now = now ?? DateTime.now;

  final OpenAiResponsesClient _responses;
  final DateTime Function() _now;

  @override
  String get id => kGeneralOpenAiProviderId;

  @override
  Future<void> collect(DataWriteContext ctx) async {
    final settings = await enabledIntegrationsForType(ctx.db, id);
    if (settings.isEmpty) {
      ctx.diagnostics.provider('general_openai: skip (disabled)');
      return;
    }

    for (final setting in settings) {
      await _collectIntegration(ctx, setting);
    }
  }

  Future<void> _collectIntegration(
    DataWriteContext ctx,
    Integration setting,
  ) async {
    final integrationId = setting.id;
    late final ProviderRuntimeConfig config;
    try {
      config = await ctx.resolveConfig(integrationId);
    } on Object catch (e, st) {
      ctx.diagnostics.providerFail('general_openai: resolveConfig', e, st);
      return;
    }

    final token = config.accessToken;
    if (token == null || token.isEmpty) {
      ctx.diagnostics.provider('general_openai: skip (no API token)');
      return;
    }

    final extra = GeneralOpenAiExtraConfig.parse(config.configJson);
    if (extra.prompts.isEmpty) {
      ctx.diagnostics.provider('general_openai: skip (no prompts)');
      return;
    }

    final nowMs = _now().millisecondsSinceEpoch;
    final kvStore = GeneralOpenAiKvStore.fromDb(ctx.db);
    final baseUrl =
        (config.baseUrl != null && config.baseUrl!.trim().isNotEmpty)
            ? config.baseUrl!.trim()
            : kDefaultOpenAiBaseUrl;
    final uri = Uri.parse('$baseUrl/responses');

    for (final prompt in extra.prompts) {
      if (!prompt.enabled) {
        continue;
      }
      if (prompt.pollSeconds > 0) {
        final last = await kvStore.readPromptLastCollectMs(
          integrationId: integrationId,
          promptId: prompt.id,
        );
        if (last != null && nowMs - last < prompt.pollSeconds * 1000) {
          ctx.diagnostics.provider(
            'general_openai: skip prompt=${prompt.id} poll gate',
          );
          continue;
        }
      }

      await _runPrompt(
        ctx: ctx,
        integrationId: integrationId,
        prompt: prompt,
        extra: extra,
        token: token,
        uri: uri,
        kvStore: kvStore,
        nowMs: nowMs,
      );

      final purged = await kvStore.purgePromptHistory(
        integrationId: integrationId,
        promptId: prompt.id,
        retentionDays: extra.retentionDaysFor(prompt),
        maxHistoryEntries: extra.maxHistoryEntriesFor(prompt),
        nowMs: nowMs,
      );
      if (purged > 0) {
        ctx.diagnostics.provider(
          'general_openai: purged $purged history key(s) prompt=${prompt.id}',
        );
      }
    }
  }

  Future<void> _runPrompt({
    required DataWriteContext ctx,
    required String integrationId,
    required GeneralOpenAiPromptConfig prompt,
    required GeneralOpenAiExtraConfig extra,
    required String token,
    required Uri uri,
    required GeneralOpenAiKvStore kvStore,
    required int nowMs,
  }) async {
    final model = extra.modelFor(prompt);
    ctx.diagnostics.provider(
      'general_openai: POST ${safeHttpUriForLog(uri)} prompt=${prompt.id} model=$model',
    );

    final input = <Map<String, Object?>>[];
    final system = prompt.systemPrompt?.trim();
    if (system != null && system.isNotEmpty) {
      input.add({'role': 'system', 'content': system});
    }
    input.add({'role': 'user', 'content': prompt.userPrompt});

    final body = <String, Object?>{
      'model': model,
      'input': input,
    };
    if (prompt.temperature != null) {
      body['temperature'] = prompt.temperature;
    }
    if (prompt.maxOutputTokens != null) {
      body['max_output_tokens'] = prompt.maxOutputTokens;
    }
    final format = prompt.responseFormat?.trim();
    if (format == 'json_object') {
      body['text'] = {
        'format': {'type': 'json_object'},
      };
    }
    if (prompt.mcpServers.isNotEmpty) {
      body['tools'] = await buildGeneralOpenAiMcpTools(
        ctx: ctx,
        integrationId: integrationId,
        servers: prompt.mcpServers,
      );
    }

    try {
      final result = await _responses.createResponse(
        uri: uri,
        bearerToken: token,
        body: body,
      );
      if (result == null) {
        await kvStore.writePromptError(
          integrationId: integrationId,
          promptId: prompt.id,
          message: 'OpenAI Responses API returned no output',
          atMs: nowMs,
        );
        return;
      }

      var value = result.outputText;
      var valueType = kIntegrationKvTypeString;
      if (format == 'json_object') {
        valueType = kIntegrationKvTypeJson;
        final trimmed = value.trim();
        if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) {
          value = jsonEncode({'text': value});
        }
      }

      await kvStore.writePromptResult(
        integrationId: integrationId,
        promptId: prompt.id,
        value: value,
        collectedAtMs: nowMs,
        valueType: valueType,
      );
      ctx.diagnostics.provider(
        'general_openai: stored prompt=${prompt.id} len=${value.length}',
      );
    } on Object catch (e, st) {
      ctx.diagnostics.providerFail('general_openai: prompt ${prompt.id}', e, st);
      await kvStore.writePromptError(
        integrationId: integrationId,
        promptId: prompt.id,
        message: '$e',
        atMs: nowMs,
      );
    }
  }
}
