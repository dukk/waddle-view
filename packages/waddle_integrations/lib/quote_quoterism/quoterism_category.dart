import 'package:drift/drift.dart';
import 'package:waddle_shared/persistence/database.dart';

/// Parsed Quoterism category reference from API payloads.
class QuoterismCategoryRef {
  const QuoterismCategoryRef({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;
}

/// Maps Quoterism category slug/id/name to a stable [ContentCategories.id].
String quoterismContentCategoryId({
  String? id,
  String? slug,
  String? name,
}) {
  final raw = (slug ?? id ?? name ?? '').trim().toLowerCase();
  if (raw.isEmpty) {
    return 'quoterism_general';
  }
  final buf = StringBuffer('quoterism_');
  for (final codeUnit in raw.codeUnits) {
    final ch = String.fromCharCode(codeUnit);
    if ((codeUnit >= 97 && codeUnit <= 122) ||
        (codeUnit >= 48 && codeUnit <= 57)) {
      buf.write(ch);
    } else {
      buf.write('_');
    }
  }
  var out = buf.toString().replaceAll(RegExp('_+'), '_');
  if (out.endsWith('_')) {
    out = out.substring(0, out.length - 1);
  }
  if (out.length > 64) {
    out = out.substring(0, 64);
  }
  return out.isEmpty ? 'quoterism_general' : out;
}

List<QuoterismCategoryRef> parseQuoterismCategories(dynamic value) {
  if (value == null) {
    return const [];
  }
  if (value is String) {
    final label = value.trim();
    if (label.isEmpty) {
      return const [];
    }
    final id = quoterismContentCategoryId(name: label);
    return [QuoterismCategoryRef(id: id, label: label)];
  }
  if (value is! List) {
    return const [];
  }
  final out = <QuoterismCategoryRef>[];
  final seen = <String>{};
  for (final item in value) {
    if (item is String) {
      final label = item.trim();
      if (label.isEmpty) continue;
      final id = quoterismContentCategoryId(name: label);
      if (seen.add(id)) {
        out.add(QuoterismCategoryRef(id: id, label: label));
      }
      continue;
    }
    if (item is! Map) {
      continue;
    }
    final slug = item['slug']?.toString();
    final idRaw = item['id']?.toString();
    final name = (item['name'] ?? item['label'] ?? item['title'])?.toString();
    final label = (name ?? slug ?? idRaw ?? '').trim();
    if (label.isEmpty) {
      continue;
    }
    final id = quoterismContentCategoryId(id: idRaw, slug: slug, name: label);
    if (seen.add(id)) {
      out.add(QuoterismCategoryRef(id: id, label: label));
    }
  }
  return out;
}

/// Ensures [ContentCategories] contains [id]; inserts when missing.
Future<void> ensureQuoterismContentCategory(
  AppDatabase db, {
  required String id,
  required String label,
}) async {
  final existing = await (db.select(db.contentCategories)
        ..where((t) => t.id.equals(id)))
      .getSingleOrNull();
  if (existing != null) {
    return;
  }
  await db.into(db.contentCategories).insertOnConflictUpdate(
        ContentCategoriesCompanion.insert(
          id: id,
          label: label,
          materialIconName: const Value('format_quote'),
        ),
      );
}
