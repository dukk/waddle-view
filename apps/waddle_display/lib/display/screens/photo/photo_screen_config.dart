/// Screen [config_json] keys shared by photo-family slide widgets.
const kShowPhotographerOverlayConfigKey = 'showPhotographerOverlay';

/// Tolerant bool reader for photo/video screen config (bool, 0/1, on/off strings).
bool photoScreenConfigBool(
  Map<String, dynamic> config,
  String key, {
  required bool defaultValue,
}) {
  final v = config[key];
  if (v is bool) {
    return v;
  }
  if (v is int) {
    return v != 0;
  }
  if (v is String) {
    final n = v.trim().toLowerCase();
    if (n == '1' || n == 'true' || n == 'yes' || n == 'on') {
      return true;
    }
    if (n == '0' || n == 'false' || n == 'no' || n == 'off') {
      return false;
    }
  }
  return defaultValue;
}

bool showPhotographerOverlayFromConfig(Map<String, dynamic> config) =>
    photoScreenConfigBool(
      config,
      kShowPhotographerOverlayConfigKey,
      defaultValue: false,
    );
