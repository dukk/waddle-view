import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';

import '../../dashboard_viewport_scope.dart';
import '../../viewer_invite_runtime.dart';

/// Builds `…/join?api=…&secret=…` for the controller self-service flow.
Uri? buildControllerJoinUri({
  required String controllerBaseUrl,
  required String displayApiBaseUrl,
  required String viewerRegistrationSecret,
}) {
  var trimmed = controllerBaseUrl.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  if (!trimmed.contains('://')) {
    trimmed = 'http://$trimmed';
  }
  Uri root;
  try {
    root = Uri.parse(trimmed);
  } on FormatException {
    return null;
  }
  if (!root.hasScheme || root.host.isEmpty) {
    return null;
  }
  final path = root.path;
  final joinPath = path.endsWith('/') ? '${path}join' : '$path/join';
  final qp = <String, String>{'api': displayApiBaseUrl};
  if (viewerRegistrationSecret.isNotEmpty) {
    qp['secret'] = viewerRegistrationSecret;
  }
  return root.replace(path: joinPath, queryParameters: qp);
}

/// Slide that advertises waddle_controller and shows a QR for the `/join` flow.
class ControllerInviteSlideWidget extends StatelessWidget {
  const ControllerInviteSlideWidget({
    super.key,
    required this.displayApiBaseUrl,
    required this.viewerInviteRuntime,
    required this.spec,
    required this.theme,
  });

  final String displayApiBaseUrl;
  final ViewerInviteRuntime viewerInviteRuntime;
  final ParsedWidgetSpec spec;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final s = DashboardViewportScope.scaleOf(context);
    final headline = spec.config['headline'] as String? ??
        'Control this display with waddle_controller';
    final body = spec.config['body'] as String? ??
        'Scan the QR code on your phone to open the operator web app, then '
        'create a read-only viewer account or sign in with an existing user.';
    final configController =
        (spec.config['controllerUrl'] as String?)?.trim() ?? '';
    final effectiveController = configController.isNotEmpty
        ? configController
        : viewerInviteRuntime.controllerPublicUrl.trim();
    final joinUri = buildControllerJoinUri(
      controllerBaseUrl: effectiveController,
      displayApiBaseUrl: displayApiBaseUrl,
      viewerRegistrationSecret: viewerInviteRuntime.viewerRegistrationSecret,
    );
    final qrData = joinUri?.toString();
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(16 * s),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              headline,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12 * s),
            Text(
              body,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16 * s),
            if (qrData != null) ...[
              Container(
                color: Colors.white,
                padding: EdgeInsets.all(12 * s),
                child: QrImageView(
                  data: qrData,
                  size: 220 * s,
                  padding: EdgeInsets.all(4 * s),
                ),
              ),
              SizedBox(height: 12 * s),
              SelectableText(
                qrData,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ] else
              Text(
                'Set WADDLE_DISPLAY_CONTROLLER_PUBLIC_URL on this display (or add '
                'controllerUrl to this screen config) so the join link can be generated.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            if (viewerInviteRuntime.viewerRegistrationSecret.isEmpty) ...[
              SizedBox(height: 16 * s),
              Text(
                'Self-service viewer signup is disabled until '
                'WADDLE_DISPLAY_VIEWER_REGISTRATION_SECRET is set on this display. '
                'You can still use the link to sign in.',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
