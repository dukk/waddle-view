import 'package:meta/meta.dart';

/// Merged non-secret row + resolved secrets for one provider tick.
@immutable
class ProviderRuntimeConfig {
  const ProviderRuntimeConfig({
    required this.providerId,
    required this.providerType,
    required this.pollSeconds,
    this.baseUrl,
    this.extraJson,
    this.accessToken,
  });

  final String providerId;
  final String providerType;
  final int pollSeconds;
  final String? baseUrl;
  final String? extraJson;
  final String? accessToken;

  /// Safe for logs — excludes tokens.
  String describeForLogs() {
    final buf = StringBuffer('ProviderRuntimeConfig(')
      ..write('id=$providerId type=$providerType poll=$pollSeconds')
      ..write(baseUrl == null ? '' : ' baseUrl=$baseUrl')
      ..write(extraJson == null ? '' : ' extra=<redacted len=${extraJson!.length}>')
      ..write(' token=${accessToken == null ? 'absent' : '<redacted>'})');
    return buf.toString();
  }
}
