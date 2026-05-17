import 'dart:convert';
import 'dart:io';

/// Parsed `manifest.json` for a drop-in display plugin.
class PluginManifest {
  const PluginManifest({
    required this.id,
    required this.version,
    required this.capabilities,
    this.minDisplayVersion,
    this.integrations = const [],
    this.screenTypes = const [],
    this.tickerSources = const [],
    this.overlays = const [],
    this.runtimeSignals = const [],
    this.sidecar,
  });

  final String id;
  final String version;
  final List<String> capabilities;
  final String? minDisplayVersion;
  final List<PluginIntegrationManifest> integrations;
  final List<PluginScreenTypeManifest> screenTypes;
  final List<PluginTickerSourceManifest> tickerSources;
  final List<PluginOverlayManifest> overlays;
  final List<PluginRuntimeSignalManifest> runtimeSignals;
  final PluginSidecarManifest? sidecar;

  bool hasCapability(String cap) =>
      capabilities.map((c) => c.trim().toLowerCase()).contains(cap.toLowerCase());

  static PluginManifest fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as String?)?.trim() ?? '';
    if (id.isEmpty) {
      throw FormatException('manifest.id is required');
    }
    return PluginManifest(
      id: id,
      version: (json['version'] as String?)?.trim() ?? '0.0.0',
      minDisplayVersion: (json['min_display_version'] as String?)?.trim(),
      capabilities: [
        for (final c in (json['capabilities'] as List<dynamic>? ?? const []))
          c.toString(),
      ],
      integrations: [
        for (final e in (json['integrations'] as List<dynamic>? ?? const []))
          PluginIntegrationManifest.fromJson(e as Map<String, dynamic>),
      ],
      screenTypes: [
        for (final e in (json['screen_types'] as List<dynamic>? ?? const []))
          PluginScreenTypeManifest.fromJson(e as Map<String, dynamic>),
      ],
      tickerSources: [
        for (final e in (json['ticker_sources'] as List<dynamic>? ?? const []))
          PluginTickerSourceManifest.fromJson(e as Map<String, dynamic>),
      ],
      overlays: [
        for (final e in (json['overlays'] as List<dynamic>? ?? const []))
          PluginOverlayManifest.fromJson(e as Map<String, dynamic>),
      ],
      runtimeSignals: [
        for (final e
            in (json['runtime_signals'] as List<dynamic>? ?? const []))
          PluginRuntimeSignalManifest.fromJson(e as Map<String, dynamic>),
      ],
      sidecar: json['sidecar'] is Map<String, dynamic>
          ? PluginSidecarManifest.fromJson(json['sidecar'] as Map<String, dynamic>)
          : null,
    );
  }

  static Future<PluginManifest> loadDirectory(String dirPath) async {
    final file = File('$dirPath/manifest.json');
    if (!await file.exists()) {
      throw FileSystemException('manifest.json not found', dirPath);
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('manifest.json must be a JSON object');
    }
    return fromJson(decoded);
  }
}

class PluginIntegrationManifest {
  const PluginIntegrationManifest({
    required this.id,
    required this.integrationType,
  });

  final String id;
  final String integrationType;

  factory PluginIntegrationManifest.fromJson(Map<String, dynamic> json) {
    return PluginIntegrationManifest(
      id: (json['id'] as String?)?.trim() ?? '',
      integrationType:
          (json['integration_type'] as String? ?? json['provider_type'] as String?)
              ?.trim() ??
          'plugin_http',
    );
  }
}

class PluginScreenTypeManifest {
  const PluginScreenTypeManifest({
    required this.type,
    this.screenId,
    this.stateEndpoint,
  });

  final String type;
  final String? screenId;
  final String? stateEndpoint;

  factory PluginScreenTypeManifest.fromJson(Map<String, dynamic> json) {
    return PluginScreenTypeManifest(
      type: (json['type'] as String?)?.trim() ?? 'plugin_template',
      screenId: (json['screen_id'] as String?)?.trim(),
      stateEndpoint: (json['state_url'] as String?)?.trim(),
    );
  }
}

class PluginTickerSourceManifest {
  const PluginTickerSourceManifest({required this.type, this.endpoint});

  final String type;
  final String? endpoint;

  factory PluginTickerSourceManifest.fromJson(Map<String, dynamic> json) {
    return PluginTickerSourceManifest(
      type: (json['type'] as String?)?.trim() ?? 'plugin',
      endpoint: (json['endpoint'] as String?)?.trim(),
    );
  }
}

class PluginOverlayManifest {
  const PluginOverlayManifest({
    required this.overlayType,
    required this.layer,
    required this.renderer,
    this.configSchema,
  });

  final String overlayType;
  final String layer;
  final String renderer;
  final String? configSchema;

  factory PluginOverlayManifest.fromJson(Map<String, dynamic> json) {
    return PluginOverlayManifest(
      overlayType: (json['overlay_type'] as String?)?.trim() ?? '',
      layer: (json['layer'] as String?)?.trim() ?? 'celebration',
      renderer: (json['renderer'] as String?)?.trim() ?? 'plugin_template',
      configSchema: (json['config_schema'] as String?)?.trim(),
    );
  }
}

class PluginRuntimeSignalManifest {
  const PluginRuntimeSignalManifest({
    required this.predicateId,
    this.source = 'sidecar',
  });

  final String predicateId;
  final String source;

  factory PluginRuntimeSignalManifest.fromJson(Map<String, dynamic> json) {
    return PluginRuntimeSignalManifest(
      predicateId: (json['predicate_id'] as String?)?.trim() ?? '',
      source: (json['source'] as String?)?.trim() ?? 'sidecar',
    );
  }
}

class PluginSidecarManifest {
  const PluginSidecarManifest({
    required this.executable,
    this.healthUrl,
    this.port,
  });

  final String executable;
  final String? healthUrl;
  final int? port;

  factory PluginSidecarManifest.fromJson(Map<String, dynamic> json) {
    return PluginSidecarManifest(
      executable: (json['executable'] as String?)?.trim() ?? '',
      healthUrl: (json['health_url'] as String?)?.trim(),
      port: json['port'] is int ? json['port'] as int : null,
    );
  }
}
