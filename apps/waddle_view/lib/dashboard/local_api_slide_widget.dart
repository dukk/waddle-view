import 'package:flutter/material.dart';

import '../curator/screen_layout_parse.dart';

/// Developer slide: loopback REST base URL and API key file hint.
class LocalApiSlideWidget extends StatelessWidget {
  const LocalApiSlideWidget({
    super.key,
    required this.baseUrl,
    required this.spec,
    required this.theme,
  });

  final String baseUrl;
  final ParsedWidgetSpec spec;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final headline =
        spec.config['headline'] as String? ?? 'Local REST API';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.api_outlined,
            size: 56,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            headline,
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SelectableText(
            baseUrl,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Use header X-Api-Key with the key from waddle_api.key '
            '(application support directory).',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
