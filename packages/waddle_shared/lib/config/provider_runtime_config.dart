import 'package:meta/meta.dart';

/// Merged non-secret row + resolved secrets for one provider tick.
@immutable
class ProviderRuntimeConfig {
  const ProviderRuntimeConfig({
    required this.providerId,
    required this.integrationType,
    required this.pollSeconds,
    this.baseUrl,
    this.configJson,
    this.accessToken,
  });

  final String providerId;
  final String integrationType;
  final int pollSeconds;
  final String? baseUrl;
  final String? configJson;
  final String? accessToken;

  /// Safe for logs — excludes tokens.
  String describeForLogs() {
    final buf = StringBuffer('ProviderRuntimeConfig(')
      ..write('id=$providerId type=$integrationType poll=$pollSeconds')
      ..write(baseUrl == null ? '' : ' baseUrl=$baseUrl')
      ..write(configJson == null ? '' : ' config=<redacted len=${configJson!.length}>')
      ..write(' token=${accessToken == null ? 'absent' : '<redacted>'})');
    return buf.toString();
  }
}
