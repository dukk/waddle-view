/// Environment variable names for the waddle_display process (HTTP, TLS, CORS, invites).
///
/// Static provider API keys and OAuth public client ids use the matching
/// `waddle*Env` constants in
/// `package:waddle_shared/config/provider_access_token_env.dart` (`WADDLE_DISPLAY_*`).
library;

const String kDisplayHttpBindIpEnv = 'WADDLE_DISPLAY_HTTP_BIND_IP';
const String kDisplayHttpPortEnv = 'WADDLE_DISPLAY_HTTP_PORT';
const String kDisplayHttpTlsEnv = 'WADDLE_DISPLAY_HTTP_TLS';
const String kDisplayHttpTlsDirEnv = 'WADDLE_DISPLAY_HTTP_TLS_DIR';
const String kDisplayHttpTlsCertEnv = 'WADDLE_DISPLAY_HTTP_TLS_CERT';
const String kDisplayHttpTlsKeyEnv = 'WADDLE_DISPLAY_HTTP_TLS_KEY';
const String kDisplayHttpCorsOriginsEnv = 'WADDLE_DISPLAY_HTTP_CORS_ORIGINS';
const String kDisplayControllerPublicUrlEnv = 'WADDLE_DISPLAY_CONTROLLER_PUBLIC_URL';
const String kDisplayViewerRegistrationSecretEnv =
    'WADDLE_DISPLAY_VIEWER_REGISTRATION_SECRET';
const String kDisplayPexelsVideoMaxTexturePixelsEnv =
    'WADDLE_DISPLAY_PEXELS_VIDEO_MAX_TEXTURE_PIXELS';
const String kDisplayPexelsVideoHwdecEnv = 'WADDLE_DISPLAY_PEXELS_VIDEO_HWDEC';
const String kDisplayAppleClientIdEnv = 'WADDLE_DISPLAY_APPLE_CLIENT_ID';
