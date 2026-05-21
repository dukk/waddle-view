import 'package:waddle_shared/config/mealviewer_kv.dart' show mealviewerNormalizeBlockKey;

/// One calendar row derived from a MealViewer menu block on a given day.
class ParsedMealviewerMenuEvent {
  const ParsedMealviewerMenuEvent({
    required this.dateKey,
    required this.startUtc,
    required this.endUtc,
    required this.blockName,
    required this.blockKey,
    required this.title,
    this.description,
    required this.externalId,
  });

  final String dateKey;
  final DateTime startUtc;
  final DateTime endUtc;
  final String blockName;
  final String blockKey;
  final String title;
  final String? description;
  final String externalId;
}

const int kMealviewerTitleMaxLength = 240;
const int kMealviewerDescriptionMaxLength = 4000;

/// Parses menu JSON from `GET /api/v4/school/{slug}/{start}/{end}/`.
List<ParsedMealviewerMenuEvent> parseMealviewerMenuEvents({
  required Map<String, dynamic> root,
  required String schoolLabel,
}) {
  final schedules = root['menuSchedules'];
  if (schedules is! List<dynamic>) {
    return const [];
  }
  final out = <ParsedMealviewerMenuEvent>[];
  for (final scheduleRaw in schedules) {
    if (scheduleRaw is! Map<String, dynamic>) {
      continue;
    }
    final dateInfo = scheduleRaw['dateInformation'];
    if (dateInfo is! Map<String, dynamic>) {
      continue;
    }
    final dateFull = dateInfo['dateFull'];
    if (dateFull is! String || dateFull.trim().isEmpty) {
      continue;
    }
    final parsedDate = DateTime.tryParse(dateFull);
    if (parsedDate == null) {
      continue;
    }
    final dayUtc = DateTime.utc(
      parsedDate.year,
      parsedDate.month,
      parsedDate.day,
    );
    final dateKey =
        '${dayUtc.year.toString().padLeft(4, '0')}-'
        '${dayUtc.month.toString().padLeft(2, '0')}-'
        '${dayUtc.day.toString().padLeft(2, '0')}';
    final endUtc = dayUtc.add(const Duration(days: 1));

    final blocks = scheduleRaw['menuBlocks'];
    if (blocks is! List<dynamic>) {
      continue;
    }
    for (final blockRaw in blocks) {
      if (blockRaw is! Map<String, dynamic>) {
        continue;
      }
      final blockName = (blockRaw['blockName'] as String?)?.trim() ?? 'Menu';
      final blockKey = mealviewerNormalizeBlockKey(blockName);
      final items = _foodItemsFromBlock(blockRaw);
      if (items.isEmpty) {
        continue;
      }
      final names = <String>[];
      final descLines = <String>[];
      for (final item in items) {
        final name = (item['item_Name'] as String?)?.trim();
        if (name == null || name.isEmpty) {
          continue;
        }
        if (!names.contains(name)) {
          names.add(name);
        }
        final type = (item['item_Type'] as String?)?.trim();
        if (type != null && type.isNotEmpty) {
          descLines.add('$name ($type)');
        } else {
          descLines.add(name);
        }
      }
      if (names.isEmpty) {
        continue;
      }
      final itemList = names.join(', ');
      var title = '$schoolLabel — $blockName: $itemList';
      if (title.length > kMealviewerTitleMaxLength) {
        title = '${title.substring(0, kMealviewerTitleMaxLength - 1)}…';
      }
      var description = descLines.join('\n');
      if (description.length > kMealviewerDescriptionMaxLength) {
        description =
            '${description.substring(0, kMealviewerDescriptionMaxLength - 1)}…';
      }
      final externalId = '$dateKey:$blockKey';
      out.add(
        ParsedMealviewerMenuEvent(
          dateKey: dateKey,
          startUtc: dayUtc,
          endUtc: endUtc,
          blockName: blockName,
          blockKey: blockKey,
          title: title,
          description: description.isEmpty ? null : description,
          externalId: externalId,
        ),
      );
    }
  }
  return out;
}

List<Map<String, dynamic>> _foodItemsFromBlock(Map<String, dynamic> block) {
  final cafeteria = block['cafeteriaLineList'];
  if (cafeteria is! Map<String, dynamic>) {
    return const [];
  }
  final data = cafeteria['data'];
  if (data is! List<dynamic> || data.isEmpty) {
    return const [];
  }
  final out = <Map<String, dynamic>>[];
  for (final line in data) {
    if (line is! Map<String, dynamic>) {
      continue;
    }
    final foodList = line['foodItemList'];
    if (foodList is! Map<String, dynamic>) {
      continue;
    }
    final items = foodList['data'];
    if (items is! List<dynamic>) {
      continue;
    }
    for (final item in items) {
      if (item is Map<String, dynamic>) {
        out.add(item);
      }
    }
  }
  return out;
}
