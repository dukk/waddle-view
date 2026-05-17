class DisplayClientConfig {
  const DisplayClientConfig({
    required this.baseUrl,
    this.bearerToken,
    this.pluginId,
  });

  final String baseUrl;
  final String? bearerToken;
  final String? pluginId;
}
