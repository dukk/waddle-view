import '../persistence/tables.dart';

/// Output style for censored words; configurable via the
/// [kRejectCensorFormatKvKey] [ConfigKeyValues] row.
enum CensorFormat {
  /// `damn` -> `****` (asterisks, same length as the matched word).
  asterisksFull,

  /// `damn` -> `****` (always four asterisks regardless of length).
  asterisksFixed,

  /// `damn` -> `d**n` (keep first and last char, mask middle; words <= 2 chars
  /// fall back to all asterisks).
  firstLast,

  /// `damn` -> `[censored]`.
  bracketedToken,
}

/// Lightweight value object decoupling the curation/filter helpers from
/// Drift-generated row classes. Loaded once per curator refresh from
/// [RejectTermRepository].
class RejectFilterTerm {
  const RejectFilterTerm({
    required this.term,
    required this.action,
  });

  /// Lowercased single word.
  final String term;

  /// One of [kRejectTermActionCensor] or [kRejectTermActionBlock].
  final String action;
}

/// Parses a [ConfigKeyValues] value from [kRejectCensorFormatKvKey] into the
/// matching [CensorFormat]; unknown/empty values fall back to
/// [CensorFormat.asterisksFull].
CensorFormat parseCensorFormatKv(String? value) {
  switch ((value ?? '').trim()) {
    case kRejectCensorFormatAsterisksFull:
      return CensorFormat.asterisksFull;
    case kRejectCensorFormatAsterisksFixed:
      return CensorFormat.asterisksFixed;
    case kRejectCensorFormatFirstLast:
      return CensorFormat.firstLast;
    case kRejectCensorFormatBracketedToken:
      return CensorFormat.bracketedToken;
    default:
      return CensorFormat.asterisksFull;
  }
}

/// Replaces every whole-word, case-insensitive occurrence of any [terms] in
/// [body] whose [RejectFilterTerm.action] is [kRejectTermActionCensor] with
/// the mask determined by [format]. Block-only terms are ignored here (they
/// already led to the row being marked `suppressed = true`). Returns [body]
/// unchanged when there are no censor terms or no matches.
String censorText(
  String body,
  Iterable<RejectFilterTerm> terms,
  CensorFormat format,
) {
  if (body.isEmpty) {
    return body;
  }
  final censorTerms = <String>[
    for (final t in terms)
      if (t.action == kRejectTermActionCensor && t.term.trim().isNotEmpty)
        t.term.trim(),
  ];
  if (censorTerms.isEmpty) {
    return body;
  }
  final pattern = _buildPattern(censorTerms);
  if (pattern == null) {
    return body;
  }
  return body.replaceAllMapped(
    pattern,
    (m) => _applyCensorFormat(m.group(0)!, format),
  );
}

/// True when [body] contains any whole-word, case-insensitive match for a
/// [terms] entry whose [RejectFilterTerm.action] is [kRejectTermActionBlock].
bool hasBlockMatch(String body, Iterable<RejectFilterTerm> terms) {
  if (body.isEmpty) {
    return false;
  }
  final blockTerms = <String>[
    for (final t in terms)
      if (t.action == kRejectTermActionBlock && t.term.trim().isNotEmpty)
        t.term.trim(),
  ];
  if (blockTerms.isEmpty) {
    return false;
  }
  final pattern = _buildPattern(blockTerms);
  if (pattern == null) {
    return false;
  }
  return pattern.hasMatch(body);
}

/// Variant of [hasBlockMatch] over multiple optional/nullable body strings;
/// returns true if any non-empty entry matches.
bool hasBlockMatchAny(Iterable<String?> bodies, Iterable<RejectFilterTerm> terms) {
  for (final b in bodies) {
    if (b == null) {
      continue;
    }
    if (hasBlockMatch(b, terms)) {
      return true;
    }
  }
  return false;
}

/// Lowercases [url] and replaces `-`, `_`, `/`, `?`, `=`, `&`, `.`, and other
/// URL punctuation with single spaces so the whole-word matcher can find
/// embedded words (e.g. `holy-damn-vista_2024.jpg` -> `holy damn vista 2024 jpg`).
/// Null/empty input returns the empty string.
String normalizeForUrlMatch(String? url) {
  if (url == null) {
    return '';
  }
  final trimmed = url.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  final lowered = trimmed.toLowerCase();
  final replaced = lowered.replaceAll(RegExp(r'[\-_/?=&.:#%+,;]+'), ' ');
  return replaced.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// True if ANY [terms] entry (regardless of [RejectFilterTerm.action]) matches
/// [photographer], [altText], or any of [urls] (after [normalizeForUrlMatch]).
/// Matching uses whole-word, case-insensitive boundaries. Images and videos
/// cannot be censored, so any match causes the curator to mark the row
/// `suppressed = true`.
bool mediaMatchesAnyTerm({
  required String? photographer,
  required String? altText,
  required Iterable<String?> urls,
  required Iterable<RejectFilterTerm> terms,
}) {
  final allTerms = <String>[
    for (final t in terms)
      if (t.term.trim().isNotEmpty) t.term.trim(),
  ];
  if (allTerms.isEmpty) {
    return false;
  }
  final pattern = _buildPattern(allTerms);
  if (pattern == null) {
    return false;
  }
  final candidates = <String>[
    if (photographer != null && photographer.trim().isNotEmpty)
      // Treat photographer separators like a URL so `Jane-Damn-Smith` matches.
      normalizeForUrlMatch(photographer),
    if (altText != null && altText.trim().isNotEmpty) altText.trim(),
    for (final u in urls) normalizeForUrlMatch(u),
  ];
  for (final c in candidates) {
    if (c.isEmpty) {
      continue;
    }
    if (pattern.hasMatch(c)) {
      return true;
    }
  }
  return false;
}

RegExp? _buildPattern(List<String> rawTerms) {
  final escaped = <String>[];
  for (final t in rawTerms) {
    final trimmed = t.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    escaped.add(RegExp.escape(trimmed));
  }
  if (escaped.isEmpty) {
    return null;
  }
  return RegExp('\\b(?:${escaped.join('|')})\\b', caseSensitive: false);
}

String _applyCensorFormat(String matched, CensorFormat format) {
  switch (format) {
    case CensorFormat.asterisksFull:
      return '*' * matched.length;
    case CensorFormat.asterisksFixed:
      return '****';
    case CensorFormat.firstLast:
      if (matched.length <= 2) {
        return '*' * matched.length;
      }
      final mid = '*' * (matched.length - 2);
      return '${matched[0]}$mid${matched[matched.length - 1]}';
    case CensorFormat.bracketedToken:
      return '[censored]';
  }
}
