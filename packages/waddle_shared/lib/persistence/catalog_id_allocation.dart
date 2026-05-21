/// Slugify an operator-facing catalog name into a stable row id fragment.
///
/// [digitPrefix] is prepended when the slug would not start with a letter
/// (e.g. `o_` for overlays, `s_` for screens, `t_` for ticker tapes).
String slugifyCatalogName(String name, {String digitPrefix = 'c_'}) {
  var normalized = name.trim().toLowerCase();
  normalized = normalized
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '')
      .replaceAll(RegExp(r'_+'), '_');
  if (normalized.length > 63) {
    normalized = normalized.substring(0, 63);
  }
  if (normalized.isEmpty) {
    return '';
  }
  if (!RegExp(r'^[a-z]').hasMatch(normalized)) {
    final prefixed = '$digitPrefix$normalized';
    return prefixed.length > 63 ? prefixed.substring(0, 63) : prefixed;
  }
  return normalized;
}

/// Picks a unique catalog id from [name], suffixing `_2`, `_3`, … when needed.
String allocateCatalogIdFromName(
  String name,
  Iterable<String> existingIds, {
  String digitPrefix = 'c_',
}) {
  final base = slugifyCatalogName(name, digitPrefix: digitPrefix);
  if (base.isEmpty) {
    return '';
  }
  final ids = existingIds.map((e) => e.trim()).toSet();
  if (!ids.contains(base)) {
    return base;
  }
  for (var n = 2; n < 10000; n++) {
    final suffix = '_$n';
    final maxBase = 63 - suffix.length;
    final candidate = '${base.substring(0, base.length.clamp(0, maxBase))}$suffix';
    if (!ids.contains(candidate)) {
      return candidate;
    }
  }
  return '${base.substring(0, 48)}_${DateTime.now().millisecondsSinceEpoch}';
}

String allocateScreenIdFromName(String name, Iterable<String> existingIds) =>
    allocateCatalogIdFromName(name, existingIds, digitPrefix: 's_');

String allocateTickerTapeIdFromName(String name, Iterable<String> existingIds) =>
    allocateCatalogIdFromName(name, existingIds, digitPrefix: 't_');

String allocateOverlayIdFromName(String name, Iterable<String> existingIds) =>
    allocateCatalogIdFromName(name, existingIds, digitPrefix: 'o_');
