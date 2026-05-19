import 'package:waddle_shared/collect/data_write_context.dart';
import 'package:waddle_shared/secrets/secret_store.dart';

import 'general_openai_config.dart';

/// [SecretStore] key for MCP server authorization on an integration.
String generalOpenAiMcpAuthorizationSecretKey(
  String integrationId,
  String serverLabel,
) =>
    'provider:mcp:$integrationId:${serverLabel.trim()}:authorization';

/// Builds OpenAI Responses API `tools` entries for remote MCP servers.
Future<List<Map<String, Object?>>> buildGeneralOpenAiMcpTools({
  required DataWriteContext ctx,
  required String integrationId,
  required List<GeneralOpenAiMcpServerConfig> servers,
}) async {
  final out = <Map<String, Object?>>[];
  for (final server in servers) {
    final tool = <String, Object?>{
      'type': 'mcp',
      'server_label': server.serverLabel,
      'server_url': server.serverUrl,
      'require_approval': server.requireApproval,
    };
    final desc = server.serverDescription?.trim();
    if (desc != null && desc.isNotEmpty) {
      tool['server_description'] = desc;
    }
    final auth = await _readMcpAuthorization(
      ctx.secrets,
      integrationId: integrationId,
      server: server,
    );
    if (auth != null && auth.isNotEmpty) {
      tool['authorization'] = auth;
    }
    out.add(tool);
  }
  return out;
}

Future<String?> _readMcpAuthorization(
  SecretStore secrets, {
  required String integrationId,
  required GeneralOpenAiMcpServerConfig server,
}) async {
  final custom = server.authorizationSecretKey?.trim();
  if (custom != null && custom.isNotEmpty) {
    return secrets.read('provider:mcp:$integrationId:$custom');
  }
  return secrets.read(
    generalOpenAiMcpAuthorizationSecretKey(integrationId, server.serverLabel),
  );
}
