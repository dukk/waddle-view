/// Decodes HTML/XML character references in [input], including common named
/// entities (`&rsquo;`, `&copy;`, …). Runs multiple passes so double-encoded
/// forms like `&amp;rsquo;` resolve correctly.
String decodeHtmlEntities(String input, {int maxPasses = 8}) {
  var s = input;
  for (var p = 0; p < maxPasses; p++) {
    final next = _decodeHtmlEntitiesOnce(s);
    if (next == s) {
      break;
    }
    s = next;
  }
  return s;
}

String _decodeHtmlEntitiesOnce(String input) {
  var s = input;
  s = s.replaceAllMapped(RegExp(r'&#x([0-9A-Fa-f]+);'), (m) {
    final code = int.tryParse(m[1]!, radix: 16);
    return code == null ? m[0]! : _unicodeCharOrEmpty(code);
  });
  s = s.replaceAllMapped(RegExp(r'&#([0-9]+);'), (m) {
    final code = int.tryParse(m[1]!);
    return code == null ? m[0]! : _unicodeCharOrEmpty(code);
  });
  const named = <String, String>{
    'nbsp': ' ',
    'amp': '&',
    'lt': '<',
    'gt': '>',
    'quot': '"',
    'apos': "'",
    'copy': '\u00A9',
    'reg': '\u00AE',
    'trade': '\u2122',
    'hellip': '\u2026',
    'mdash': '\u2014',
    'ndash': '\u2013',
    'lsquo': '\u2018',
    'rsquo': '\u2019',
    'sbquo': '\u201A',
    'ldquo': '\u201C',
    'rdquo': '\u201D',
    'bdquo': '\u201E',
    'lsaquo': '\u2039',
    'rsaquo': '\u203A',
    'bull': '\u2022',
    'middot': '\u00B7',
    'deg': '\u00B0',
    'plusmn': '\u00B1',
    'para': '\u00B6',
    'sect': '\u00A7',
    'euro': '\u20AC',
    'pound': '\u00A3',
    'yen': '\u00A5',
    'cent': '\u00A2',
    'agrave': '\u00E0',
    'aacute': '\u00E1',
    'acirc': '\u00E2',
    'atilde': '\u00E3',
    'auml': '\u00E4',
    'aring': '\u00E5',
    'aelig': '\u00E6',
    'ccedil': '\u00E7',
    'egrave': '\u00E8',
    'eacute': '\u00E9',
    'ecirc': '\u00EA',
    'euml': '\u00EB',
    'igrave': '\u00EC',
    'iacute': '\u00ED',
    'icirc': '\u00EE',
    'iuml': '\u00EF',
    'eth': '\u00F0',
    'ntilde': '\u00F1',
    'ograve': '\u00F2',
    'oacute': '\u00F3',
    'ocirc': '\u00F4',
    'otilde': '\u00F5',
    'ouml': '\u00F6',
    'oslash': '\u00F8',
    'ugrave': '\u00F9',
    'uacute': '\u00FA',
    'ucirc': '\u00FB',
    'uuml': '\u00FC',
    'yacute': '\u00FD',
    'thorn': '\u00FE',
    'szlig': '\u00DF',
    'frac12': '\u00BD',
    'frac14': '\u00BC',
    'frac34': '\u00BE',
  };
  s = s.replaceAllMapped(RegExp(r'&([a-zA-Z][a-zA-Z0-9]*);'), (m) {
    final key = m[1]!.toLowerCase();
    return named[key] ?? m[0]!;
  });
  return s;
}

String _unicodeCharOrEmpty(int code) {
  if (code < 0 || code > 0x10FFFF) {
    return '';
  }
  if (code == 0xA0) {
    return ' ';
  }
  if (code >= 0xD800 && code <= 0xDFFF) {
    return '';
  }
  if (code > 0xFFFF) {
    final v = code - 0x10000;
    return String.fromCharCodes(<int>[
      0xD800 + (v >> 10),
      0xDC00 + (v & 0x3FF),
    ]);
  }
  return String.fromCharCode(code);
}

/// Decodes entities in a JSON string field; non-strings yield empty.
String decodeHtmlEntitiesFromField(Object? raw) {
  if (raw is! String) {
    return '';
  }
  return decodeHtmlEntities(raw).trim();
}
