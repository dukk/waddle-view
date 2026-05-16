/// Standard Wi‑Fi QR payload (`WIFI:...`, per common Android / ZXing format).
/// Result of [parseWifiConnectionUri].
class WifiConnectionUriParseResult {
  const WifiConnectionUriParseResult._({
    required this.isValid,
    this.rawForQr,
    this.ssid,
    this.securityType,
    this.password,
    this.hidden = false,
  });

  const WifiConnectionUriParseResult.invalid()
      : this._(isValid: false);

  const WifiConnectionUriParseResult.ok({
    required String rawForQr,
    required String ssid,
    required String securityType,
    String? password,
    bool hidden = false,
  }) : this._(
          isValid: true,
          rawForQr: rawForQr,
          ssid: ssid,
          securityType: securityType,
          password: password,
          hidden: hidden,
        );

  final bool isValid;
  final String? rawForQr;
  final String? ssid;
  /// Value of the `T` field (e.g. WPA, WPA2, WPA3, nopass).
  final String? securityType;
  final String? password;
  final bool hidden;
}

/// Parses a `WIFI:T:...;S:...;P:...` connection string for QR and display.
WifiConnectionUriParseResult parseWifiConnectionUri(String? raw) {
  final s = raw?.trim() ?? '';
  if (s.isEmpty) {
    return const WifiConnectionUriParseResult.invalid();
  }
  if (!s.toUpperCase().startsWith('WIFI:')) {
    return const WifiConnectionUriParseResult.invalid();
  }
  final body = s.substring('WIFI:'.length);
  final fields = <String, String>{};
  for (final part in _splitFields(body)) {
    if (part.isEmpty) {
      continue;
    }
    final idx = _indexOfUnescapedColon(part);
    if (idx <= 0) {
      return const WifiConnectionUriParseResult.invalid();
    }
    final key = part.substring(0, idx);
    final valueRaw = part.substring(idx + 1);
    if (key.length != 1) {
      return const WifiConnectionUriParseResult.invalid();
    }
    fields[key] = _unescapeValue(valueRaw);
  }
  final ssid = fields['S'];
  if (ssid == null || ssid.isEmpty) {
    return const WifiConnectionUriParseResult.invalid();
  }
  final t = fields['T'] ?? '';
  final password = fields['P'];
  final hiddenStr = fields['H'];
  final hidden =
      hiddenStr == 'true' || hiddenStr == 'TRUE' || hiddenStr == '1';

  return WifiConnectionUriParseResult.ok(
    rawForQr: s,
    ssid: ssid,
    securityType: t.isEmpty ? 'unknown' : t,
    password: (t == 'nopass' || t == 'NOPASS') ? null : password,
    hidden: hidden,
  );
}

int _indexOfUnescapedColon(String part) {
  for (var i = 0; i < part.length; i++) {
    final c = part[i];
    if (c == r'\') {
      i++;
      continue;
    }
    if (c == ':') {
      return i;
    }
  }
  return -1;
}

/// Split `body` on `;` when not escaped as `\;`.
List<String> _splitFields(String body) {
  final out = <String>[];
  final buf = StringBuffer();
  for (var i = 0; i < body.length; i++) {
    final c = body[i];
    if (c == r'\') {
      if (i + 1 < body.length) {
        buf.write(c);
        buf.write(body[++i]);
      } else {
        buf.write(c);
      }
      continue;
    }
    if (c == ';') {
      out.add(buf.toString());
      buf.clear();
    } else {
      buf.write(c);
    }
  }
  out.add(buf.toString());
  return out;
}

String _unescapeValue(String v) {
  final buf = StringBuffer();
  for (var i = 0; i < v.length; i++) {
    final c = v[i];
    if (c == r'\') {
      if (i + 1 < v.length) {
        final n = v[i + 1];
        if (n == ';' || n == ',' || n == r'\') {
          buf.write(n);
          i++;
          continue;
        }
      }
    }
    buf.write(c);
  }
  return buf.toString();
}
