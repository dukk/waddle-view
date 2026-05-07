/// Normalizes RSS/Atom text for UI (ticker, dashboard): decodes entities,
/// strips markup, removes characters that typically render badly, and
/// collapses whitespace.
String sanitizeRssDisplayText(String? raw) {
  if (raw == null || raw.isEmpty) {
    return '';
  }
  var s = raw;
  s = decodeHtmlEntities(s);
  s = stripHtmlTags(s);
  s = removeProblematicCharacters(s);
  s = collapseWhitespace(s);
  return s.trim();
}

/// Like [sanitizeRssDisplayText], but returns `null` when the result is empty.
String? sanitizeRssOptional(String? raw) {
  final s = sanitizeRssDisplayText(raw);
  return s.isEmpty ? null : s;
}

/// Light cleanup for URLs: trim edges and strip invisible characters only.
String sanitizeRssLink(String? raw) {
  if (raw == null || raw.isEmpty) {
    return '';
  }
  return removeProblematicCharacters(raw.trim());
}

/// Decodes `&name;`, `&#decimal;`, and `&#xhex;` sequences (HTML/XML style).
String decodeHtmlEntities(String input) {
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
    'hellip': '\u2026',
    'mdash': '\u2014',
    'ndash': '\u2013',
    'lsquo': '\u2018',
    'rsquo': '\u2019',
    'ldquo': '\u201C',
    'rdquo': '\u201D',
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

/// Removes angle-bracket markup (repeat pass for shallow nesting).
String stripHtmlTags(String input) {
  var s = input;
  for (var i = 0; i < 12; i++) {
    final next = s.replaceAll(RegExp(r'<[^>]*>'), ' ');
    if (next == s) {
      break;
    }
    s = next;
  }
  return s;
}

/// Drops C0/C1 controls (except common whitespace), format characters, and BOM.
String removeProblematicCharacters(String input) {
  final buf = StringBuffer();
  for (final r in input.runes) {
    if (_stripRune(r)) {
      continue;
    }
    buf.writeCharCode(r);
  }
  return buf.toString();
}

bool _stripRune(int r) {
  if (r == 0xFEFF) {
    return true;
  }
  if (r >= 0x200B && r <= 0x200F) {
    return true;
  }
  if (r >= 0x202A && r <= 0x202E) {
    return true;
  }
  if (r >= 0x2060 && r <= 0x2064) {
    return true;
  }
  if (r < 0x20 && r != 0x9 && r != 0xA && r != 0xD) {
    return true;
  }
  if (r >= 0x7F && r <= 0x9F) {
    return true;
  }
  return false;
}

String collapseWhitespace(String input) {
  return input.replaceAll(RegExp(r'\s+'), ' ');
}
