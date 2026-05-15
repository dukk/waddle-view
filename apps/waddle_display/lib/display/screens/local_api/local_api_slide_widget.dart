import 'package:flutter/material.dart';

import 'package:waddle_shared/layout/screen_layout_parse.dart';
import '../../dashboard_viewport_scope.dart';
import '../../../theme/display_theme.dart';

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
    final palette = theme.extension<PaletteTertiaryLayers>();
    final iconColor =
        palette?.iconColor ??
        theme.iconTheme.color ??
        theme.colorScheme.onSurfaceVariant;
    final headline =
        spec.config['headline'] as String? ?? 'Local REST API';
    final s = DashboardViewportScope.scaleOf(context);

    return Padding(
      padding: EdgeInsets.only(bottom: 12 * s),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.api_outlined,
            size: 56 * s,
            color: iconColor,
          ),
          SizedBox(height: 12 * s),
          Text(
            headline,
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20 * s),
          SelectableText(
            baseUrl,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16 * s),
          Text(
            'Sign in via waddle_controller (POST /v1/auth/login) using a '
            'user account, or bootstrap user display with the instance id from '
            'waddle_instance.id in the application support directory.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
