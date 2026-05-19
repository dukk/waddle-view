import 'dart:convert';

const String kGeneralOpenAiProviderId = 'general_openai';

/// Remote HTTP MCP server entry on a prompt.
class GeneralOpenAiMcpServerConfig {
  const GeneralOpenAiMcpServerConfig({
    required this.serverLabel,
    required this.serverUrl,
    this.serverDescription,
    this.requireApproval = 'never',
    this.authorizationSecretKey,
  });

  final String serverLabel;
  final String serverUrl;
  final String? serverDescription;
  final String requireApproval;
  final String? authorizationSecretKey;

  static GeneralOpenAiMcpServerConfig? tryParse(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      return null;
    }
    final label = (raw['serverLabel'] as String?)?.trim() ?? '';
    final url = (raw['serverUrl'] as String?)?.trim() ?? '';
    if (label.isEmpty || url.isEmpty) {
      return null;
    }
    return GeneralOpenAiMcpServerConfig(
      serverLabel: label,
      serverUrl: url,
      serverDescription: (raw['serverDescription'] as String?)?.trim(),
      requireApproval:
          (raw['requireApproval'] as String?)?.trim().isNotEmpty == true
              ? (raw['requireApproval'] as String).trim()
              : 'never',
      authorizationSecretKey:
          (raw['authorizationSecretKey'] as String?)?.trim(),
    );
  }
}

/// One scheduled prompt on a [general_openai] integration.
class GeneralOpenAiPromptConfig {
  const GeneralOpenAiPromptConfig({
    required this.id,
    required this.userPrompt,
    this.label,
    this.enabled = true,
    this.pollSeconds = 3600,
    this.model,
    this.systemPrompt,
    this.temperature,
    this.maxOutputTokens,
    this.retentionDays,
    this.maxHistoryEntries,
    this.responseFormat,
    this.expectedValueType,
    this.mcpServers = const [],
  });

  final String id;
  final String? label;
  final bool enabled;
  final int pollSeconds;
  final String? model;
  final String? systemPrompt;
  final String userPrompt;
  final double? temperature;
  final int? maxOutputTokens;
  final int? retentionDays;
  final int? maxHistoryEntries;
  final String? responseFormat;
  final String? expectedValueType;
  final List<GeneralOpenAiMcpServerConfig> mcpServers;

  static GeneralOpenAiPromptConfig? tryParse(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      return null;
    }
    final id = (raw['id'] as String?)?.trim() ?? '';
    final userPrompt = (raw['userPrompt'] as String?)?.trim() ?? '';
    if (id.isEmpty || userPrompt.isEmpty) {
      return null;
    }
    final mcpRaw = raw['mcpServers'];
    final mcpServers = <GeneralOpenAiMcpServerConfig>[];
    if (mcpRaw is List<dynamic>) {
      for (final e in mcpRaw) {
        final parsed = GeneralOpenAiMcpServerConfig.tryParse(e);
        if (parsed != null) {
          mcpServers.add(parsed);
        }
      }
    }
    return GeneralOpenAiPromptConfig(
      id: id,
      label: (raw['label'] as String?)?.trim(),
      enabled: raw['enabled'] is bool ? raw['enabled'] as bool : true,
      pollSeconds: _intField(raw, 'pollSeconds', 3600),
      model: (raw['model'] as String?)?.trim(),
      systemPrompt: (raw['systemPrompt'] as String?)?.trim(),
      userPrompt: userPrompt,
      temperature: _doubleField(raw, 'temperature'),
      maxOutputTokens: _intFieldOrNull(raw, 'maxOutputTokens'),
      retentionDays: _intFieldOrNull(raw, 'retentionDays'),
      maxHistoryEntries: _intFieldOrNull(raw, 'maxHistoryEntries'),
      responseFormat: (raw['responseFormat'] as String?)?.trim(),
      expectedValueType: (raw['expectedValueType'] as String?)?.trim(),
      mcpServers: mcpServers,
    );
  }
}

/// Parsed [Integrations.configJson] for [kGeneralOpenAiProviderId].
class GeneralOpenAiExtraConfig {
  const GeneralOpenAiExtraConfig({
    required this.defaultModel,
    required this.defaultRetentionDays,
    required this.defaultMaxHistoryEntries,
    required this.prompts,
  });

  final String defaultModel;
  final int defaultRetentionDays;
  final int defaultMaxHistoryEntries;
  final List<GeneralOpenAiPromptConfig> prompts;

  static const GeneralOpenAiExtraConfig defaults = GeneralOpenAiExtraConfig(
    defaultModel: 'gpt-4o-mini',
    defaultRetentionDays: 30,
    defaultMaxHistoryEntries: 500,
    prompts: [],
  );

  static GeneralOpenAiExtraConfig parse(String? configJson) {
    if (configJson == null || configJson.trim().isEmpty) {
      return defaults;
    }
    try {
      final decoded = jsonDecode(configJson);
      return parseMap(decoded);
    } catch (_) {
      return defaults;
    }
  }

  static GeneralOpenAiExtraConfig parseMap(Object? decoded) {
    if (decoded is! Map<String, dynamic>) {
      return defaults;
    }
    final promptsRaw = decoded['prompts'];
    final prompts = <GeneralOpenAiPromptConfig>[];
    if (promptsRaw is List<dynamic>) {
      for (final e in promptsRaw) {
        final p = GeneralOpenAiPromptConfig.tryParse(e);
        if (p != null) {
          prompts.add(p);
        }
      }
    }
    return GeneralOpenAiExtraConfig(
      defaultModel: (decoded['defaultModel'] as String?)?.trim().isNotEmpty ==
              true
          ? (decoded['defaultModel'] as String).trim()
          : defaults.defaultModel,
      defaultRetentionDays:
          _intField(decoded, 'defaultRetentionDays', defaults.defaultRetentionDays),
      defaultMaxHistoryEntries: _intField(
        decoded,
        'defaultMaxHistoryEntries',
        defaults.defaultMaxHistoryEntries,
      ),
      prompts: prompts,
    );
  }

  String modelFor(GeneralOpenAiPromptConfig prompt) {
    final m = prompt.model?.trim();
    if (m != null && m.isNotEmpty) {
      return m;
    }
    return defaultModel;
  }

  int retentionDaysFor(GeneralOpenAiPromptConfig prompt) {
    final d = prompt.retentionDays;
    if (d != null && d > 0) {
      return d;
    }
    return defaultRetentionDays;
  }

  int maxHistoryEntriesFor(GeneralOpenAiPromptConfig prompt) {
    final n = prompt.maxHistoryEntries;
    if (n != null && n > 0) {
      return n;
    }
    return defaultMaxHistoryEntries;
  }
}

int _intField(Map<String, dynamic> m, String key, int def) {
  final v = m[key];
  if (v is int) {
    return v;
  }
  if (v is double) {
    return v.round();
  }
  return def;
}

int? _intFieldOrNull(Map<String, dynamic> m, String key) {
  final v = m[key];
  if (v is int) {
    return v;
  }
  if (v is double) {
    return v.round();
  }
  return null;
}

double? _doubleField(Map<String, dynamic> m, String key) {
  final v = m[key];
  if (v is num) {
    return v.toDouble();
  }
  return null;
}
