import 'dart:convert';

import 'display_overlay_clock_placement.dart';
import 'display_overlay_static_image_settings.dart';
import 'qr_overlay_payload.dart';

/// Default horizontal anchor for QR overlays (bottom-right friendly).
const double kQrOverlayPositionXDefault = 0.82;

/// Default vertical anchor for QR overlays.
const double kQrOverlayPositionYDefault = 0.78;

/// Default QR block width as fraction of viewport shortest side.
const double kQrOverlayScaleDefault = 0.22;

/// Resolved QR code overlay settings from overlay `config_json`.
class QrCodeOverlaySettings {
  const QrCodeOverlaySettings({
    required this.placement,
    required this.payload,
    required this.template,
    required this.templateFields,
    this.title = '',
    this.description = '',
  });

  static const ClockOverlayPlacement kDefaultPlacement = ClockOverlayPlacement(
    x: kQrOverlayPositionXDefault,
    y: kQrOverlayPositionYDefault,
    scale: kQrOverlayScaleDefault,
    opacity: 1.0,
  );

  static const QrCodeOverlaySettings defaults = QrCodeOverlaySettings(
    placement: kDefaultPlacement,
    payload: '',
    template: kQrOverlayTemplateCustom,
    templateFields: {},
  );

  final ClockOverlayPlacement placement;
  final String payload;
  final String template;
  final Map<String, dynamic> templateFields;
  final String title;
  final String description;

  bool get isRenderable => payload.isNotEmpty;

  Map<String, dynamic> toJson() => {
        ...placement.toJson(),
        'template': template,
        if (templateFields.isNotEmpty) 'template_fields': templateFields,
        'payload': payload,
        if (title.isNotEmpty) 'title': title,
        if (description.isNotEmpty) 'description': description,
      };

  static QrCodeOverlaySettings parse(String configJson) {
    if (configJson.trim().isEmpty) {
      return defaults;
    }
    try {
      final decoded = jsonDecode(configJson);
      if (decoded is Map<String, dynamic>) {
        return parseMap(decoded);
      }
      if (decoded is Map) {
        return parseMap(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      /* fall through */
    }
    return defaults;
  }

  static QrCodeOverlaySettings parseMap(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) {
      return defaults;
    }
    final templateRaw = raw['template'];
    final template = templateRaw is String && templateRaw.trim().isNotEmpty
        ? templateRaw.trim().toLowerCase()
        : kQrOverlayTemplateCustom;
    final fieldsRaw = raw['template_fields'];
    final templateFields = fieldsRaw is Map
        ? Map<String, dynamic>.from(fieldsRaw)
        : <String, dynamic>{};
    var payload = _readString(raw['payload']);
    if (payload.isEmpty && isQrOverlayTemplateValid(template)) {
      payload = buildQrOverlayPayload(template, templateFields);
    }
    if (payload.isEmpty) {
      final legacy = _readString(raw['data']);
      if (legacy.isNotEmpty) {
        payload = legacy;
      }
    }
    return QrCodeOverlaySettings(
      placement: _parsePlacement(raw),
      payload: payload,
      template: isQrOverlayTemplateValid(template)
          ? template
          : kQrOverlayTemplateCustom,
      templateFields: templateFields,
      title: _readString(raw['title']),
      description: _readString(raw['description']),
    );
  }
}

ClockOverlayPlacement _parsePlacement(Map<String, dynamic> raw) {
  return ClockOverlayPlacement(
    x: _clamp01(raw['x'], kQrOverlayPositionXDefault),
    y: _clamp01(raw['y'], kQrOverlayPositionYDefault),
    scale: _clampScale(raw['scale']),
    opacity: _clampOpacity(raw['opacity']),
  );
}

double _clamp01(Object? raw, double fallback) {
  final v = raw is num ? raw.toDouble() : double.tryParse('$raw');
  if (v == null || !v.isFinite) {
    return fallback;
  }
  return v.clamp(0.0, 1.0);
}

double _clampScale(Object? raw) {
  final v = raw is num ? raw.toDouble() : double.tryParse('$raw');
  if (v == null || !v.isFinite) {
    return kQrOverlayScaleDefault;
  }
  return v.clamp(kStaticImageOverlayScaleMin, kStaticImageOverlayScaleMax);
}

double _clampOpacity(Object? raw) {
  if (raw == null) {
    return 1.0;
  }
  final v = raw is num ? raw.toDouble() : double.tryParse('$raw');
  if (v == null || !v.isFinite) {
    return 1.0;
  }
  return v.clamp(0.0, 1.0);
}

String _readString(Object? raw) {
  if (raw == null) {
    return '';
  }
  if (raw is String) {
    return raw.trim();
  }
  return raw.toString().trim();
}

/// Returns `null` when [raw] is not a JSON object or violates QR overlay rules.
String? normalizeQrCodeOverlayConfigJsonString(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty || trimmed == '{}') {
    return null;
  }
  dynamic decoded;
  try {
    decoded = jsonDecode(trimmed);
  } on Object {
    return null;
  }
  if (decoded is! Map) {
    return null;
  }
  final map = decoded.cast<String, dynamic>();
  map.remove('messages');
  map.remove('message_interval_sec');
  map.remove('enabled');
  if (!_qrCodeOverlayConfigMapValid(map)) {
    return null;
  }
  final settings = _normalizeQrSettings(map);
  if (!settings.isRenderable) {
    return null;
  }
  return jsonEncode(settings.toJson());
}

QrCodeOverlaySettings _normalizeQrSettings(Map<String, dynamic> map) {
  final templateRaw = map['template'];
  final template = templateRaw is String && templateRaw.trim().isNotEmpty
      ? templateRaw.trim().toLowerCase()
      : kQrOverlayTemplateCustom;
  final validTemplate =
      isQrOverlayTemplateValid(template) ? template : kQrOverlayTemplateCustom;
  final fieldsRaw = map['template_fields'];
  final templateFields = fieldsRaw is Map
      ? Map<String, dynamic>.from(fieldsRaw)
      : <String, dynamic>{};
  var payload = buildQrOverlayPayload(validTemplate, templateFields);
  if (payload.isEmpty && validTemplate == kQrOverlayTemplateCustom) {
    payload = _readString(map['payload']);
    if (payload.isEmpty) {
      payload = _readString(templateFields['payload']);
    }
  }
  return QrCodeOverlaySettings(
    placement: _parsePlacement(map),
    payload: payload,
    template: validTemplate,
    templateFields: templateFields,
    title: _readString(map['title']),
    description: _readString(map['description']),
  );
}

bool _qrCodeOverlayConfigMapValid(Map<String, dynamic> map) {
  if (!validateClockOverlayPlacementMap(map)) {
    return false;
  }
  final templateRaw = map['template'];
  if (templateRaw != null &&
      (templateRaw is! String || !isQrOverlayTemplateValid(templateRaw))) {
    return false;
  }
  if (map['template_fields'] != null && map['template_fields'] is! Map) {
    return false;
  }
  if (map['title'] != null && map['title'] is! String) {
    return false;
  }
  if (map['description'] != null && map['description'] is! String) {
    return false;
  }
  if (map['payload'] != null && map['payload'] is! String) {
    return false;
  }
  return true;
}
