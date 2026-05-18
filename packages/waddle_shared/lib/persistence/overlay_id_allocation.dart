/// Slugify an operator-facing overlay name into a stable row id fragment.
String slugifyOverlayName(String name) {
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
    return 'o_$normalized'.substring(0, normalized.length + 2 > 63 ? 63 : normalized.length + 2);
  }
  return normalized;
}

/// Picks a unique overlay id from [name], suffixing `_2`, `_3`, … when needed.
String allocateOverlayIdFromName(String name, Iterable<String> existingIds) {
  final base = slugifyOverlayName(name);
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
