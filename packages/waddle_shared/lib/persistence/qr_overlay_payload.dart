/// Built-in QR overlay payload templates (operator-facing).
const String kQrOverlayTemplateCustom = 'custom';
const String kQrOverlayTemplateHttp = 'http';
const String kQrOverlayTemplateMailto = 'mailto';
const String kQrOverlayTemplateTel = 'tel';
const String kQrOverlayTemplateSms = 'sms';
const String kQrOverlayTemplateGeo = 'geo';
const String kQrOverlayTemplateWifi = 'wifi';
const String kQrOverlayTemplateVcard = 'vcard';
const String kQrOverlayTemplateVcalendar = 'vcalendar';

/// All supported template ids for schema and validation.
const List<String> kQrOverlayTemplateValues = [
  kQrOverlayTemplateCustom,
  kQrOverlayTemplateHttp,
  kQrOverlayTemplateMailto,
  kQrOverlayTemplateTel,
  kQrOverlayTemplateSms,
  kQrOverlayTemplateGeo,
  kQrOverlayTemplateWifi,
  kQrOverlayTemplateVcard,
  kQrOverlayTemplateVcalendar,
];

/// Builds the QR payload string from [template] and [fields].
/// Returns empty string when required inputs are missing or invalid.
String buildQrOverlayPayload(String template, Map<String, dynamic> fields) {
  final t = template.trim().toLowerCase();
  switch (t) {
    case kQrOverlayTemplateCustom:
      return _readString(fields['payload'] ?? fields['data']).trim();
    case kQrOverlayTemplateHttp:
      return _buildHttpPayload(fields);
    case kQrOverlayTemplateMailto:
      return _buildMailtoPayload(fields);
    case kQrOverlayTemplateTel:
      return _buildTelPayload(fields);
    case kQrOverlayTemplateSms:
      return _buildSmsPayload(fields);
    case kQrOverlayTemplateGeo:
      return _buildGeoPayload(fields);
    case kQrOverlayTemplateWifi:
      return _buildWifiPayload(fields);
    case kQrOverlayTemplateVcard:
      return _buildVcardPayload(fields);
    case kQrOverlayTemplateVcalendar:
      return _buildVcalendarPayload(fields);
    default:
      return '';
  }
}

String _buildHttpPayload(Map<String, dynamic> fields) {
  var url = _readString(fields['url']);
  if (url.isEmpty) {
    return '';
  }
  if (!url.contains('://')) {
    url = 'https://$url';
  }
  return url;
}

String _buildMailtoPayload(Map<String, dynamic> fields) {
  final email = _readString(fields['email']);
  if (email.isEmpty) {
    return '';
  }
  final subject = _readString(fields['subject']);
  final body = _readString(fields['body']);
  final buf = StringBuffer('mailto:$email');
  final params = <String>[];
  if (subject.isNotEmpty) {
    params.add('subject=${Uri.encodeComponent(subject)}');
  }
  if (body.isNotEmpty) {
    params.add('body=${Uri.encodeComponent(body)}');
  }
  if (params.isNotEmpty) {
    buf.write('?${params.join('&')}');
  }
  return buf.toString();
}

String _buildTelPayload(Map<String, dynamic> fields) {
  final phone = _normalizePhone(_readString(fields['phone']));
  if (phone.isEmpty) {
    return '';
  }
  return 'tel:$phone';
}

String _buildSmsPayload(Map<String, dynamic> fields) {
  final phone = _normalizePhone(_readString(fields['phone']));
  if (phone.isEmpty) {
    return '';
  }
  final body = _readString(fields['body']);
  if (body.isEmpty) {
    return 'smsto:$phone';
  }
  return 'smsto:$phone?body=${Uri.encodeComponent(body)}';
}

String _buildGeoPayload(Map<String, dynamic> fields) {
  final lat = _readString(fields['lat']);
  final lng = _readString(fields['lng']);
  if (lat.isEmpty || lng.isEmpty) {
    return '';
  }
  final label = _readString(fields['label']);
  if (label.isEmpty) {
    return 'geo:$lat,$lng';
  }
  return 'geo:$lat,$lng?q=${Uri.encodeComponent(label)}';
}

String _buildWifiPayload(Map<String, dynamic> fields) {
  final ssid = _readString(fields['ssid']);
  if (ssid.isEmpty) {
    return '';
  }
  final security = _readString(fields['securityType']);
  final t = security.isEmpty ? 'nopass' : security;
  final password = _readString(fields['password']);
  final hidden = fields['hidden'] == true;
  final buf = StringBuffer('WIFI:T:${_escapeWifiField(t)};');
  buf.write('S:${_escapeWifiField(ssid)};');
  if (t != 'nopass' && t != 'NOPASS' && password.isNotEmpty) {
    buf.write('P:${_escapeWifiField(password)};');
  }
  if (hidden) {
    buf.write('H:true;');
  }
  return buf.toString();
}

String _buildVcardPayload(Map<String, dynamic> fields) {
  final firstName = _readString(fields['firstName']);
  final lastName = _readString(fields['lastName']);
  final fullName = _readString(fields['fullName']);
  final fn = fullName.isNotEmpty
      ? fullName
      : [firstName, lastName].where((s) => s.isNotEmpty).join(' ').trim();
  if (fn.isEmpty) {
    return '';
  }
  final lines = <String>[
    'BEGIN:VCARD',
    'VERSION:3.0',
    'FN:$fn',
  ];
  final org = _readString(fields['org']);
  if (org.isNotEmpty) {
    lines.add('ORG:$org');
  }
  final phone = _readString(fields['phone']);
  if (phone.isNotEmpty) {
    lines.add('TEL:$phone');
  }
  final email = _readString(fields['email']);
  if (email.isNotEmpty) {
    lines.add('EMAIL:$email');
  }
  final title = _readString(fields['title']);
  if (title.isNotEmpty) {
    lines.add('TITLE:$title');
  }
  lines.add('END:VCARD');
  return lines.join('\n');
}

String _buildVcalendarPayload(Map<String, dynamic> fields) {
  final summary = _readString(fields['summary']);
  final dtStart = _readString(fields['dtStart']);
  final dtEnd = _readString(fields['dtEnd']);
  if (summary.isEmpty || dtStart.isEmpty || dtEnd.isEmpty) {
    return '';
  }
  final lines = <String>[
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'BEGIN:VEVENT',
    'SUMMARY:$summary',
    'DTSTART:$dtStart',
    'DTEND:$dtEnd',
  ];
  final location = _readString(fields['location']);
  if (location.isNotEmpty) {
    lines.add('LOCATION:$location');
  }
  final description = _readString(fields['description']);
  if (description.isNotEmpty) {
    lines.add('DESCRIPTION:$description');
  }
  lines
    ..add('END:VEVENT')
    ..add('END:VCALENDAR');
  return lines.join('\n');
}

String _escapeWifiField(String value) {
  final buf = StringBuffer();
  for (var i = 0; i < value.length; i++) {
    final c = value[i];
    if (c == r'\' || c == ';' || c == ',' || c == ':') {
      buf.write(r'\');
    }
    buf.write(c);
  }
  return buf.toString();
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

String _normalizePhone(String raw) {
  final trimmed = raw.replaceAll(RegExp(r'\s+'), '');
  if (trimmed.isEmpty) {
    return '';
  }
  if (trimmed.startsWith('+')) {
    return trimmed;
  }
  return trimmed;
}

bool isQrOverlayTemplateValid(String? template) {
  if (template == null || template.trim().isEmpty) {
    return false;
  }
  return kQrOverlayTemplateValues.contains(template.trim().toLowerCase());
}
