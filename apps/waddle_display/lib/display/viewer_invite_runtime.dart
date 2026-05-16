import 'package:flutter/foundation.dart';

/// Environment-derived values for [ControllerInviteSlideWidget] join QR links.
@immutable
class ViewerInviteRuntime {
  const ViewerInviteRuntime({
    required this.controllerPublicUrl,
    required this.viewerRegistrationSecret,
  });

  /// Public base URL of the waddle_controller SPA (process env
  /// `WADDLE_CONTROLLER_PUBLIC_URL`), unless overridden per screen.
  final String controllerPublicUrl;

  /// Shared secret required by [POST /v1/auth/register-viewer] (`WADDLE_VIEWER_REGISTRATION_SECRET`).
  final String viewerRegistrationSecret;
}
