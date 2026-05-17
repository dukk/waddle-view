class PluginTemplateScreenState {
  const PluginTemplateScreenState({
    required this.title,
    this.body,
    this.metrics = const [],
  });

  final String title;
  final String? body;
  final List<Map<String, String>> metrics;

  Map<String, dynamic> toJson() => {
        'v': 1,
        'title': title,
        if (body != null) 'body': body,
        if (metrics.isNotEmpty) 'metrics': metrics,
      };
}
