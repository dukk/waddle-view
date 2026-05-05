import 'package:drift/drift.dart';

import '../persistence/database.dart';

/// Idempotent default joke categories (edit rows in DB to tune seasons).
Future<void> ensureDefaultJokeCategories(AppDatabase db) async {
  for (final c in _defaultJokeCategories) {
    final existing =
        await (db.select(db.jokeCategories)..where((t) => t.id.equals(c.id)))
            .getSingleOrNull();
    if (existing != null) {
      continue;
    }
    await db.into(db.jokeCategories).insert(
          JokeCategoriesCompanion.insert(
            id: c.id,
            label: c.label,
            isSeasonal: Value(c.isSeasonal),
            startMonth: c.startMonth == null
                ? const Value.absent()
                : Value(c.startMonth),
            startDay: c.startDay == null
                ? const Value.absent()
                : Value(c.startDay),
            endMonth:
                c.endMonth == null ? const Value.absent() : Value(c.endMonth),
            endDay: c.endDay == null ? const Value.absent() : Value(c.endDay),
            categoryPrompt: c.categoryPrompt == null
                ? const Value.absent()
                : Value(c.categoryPrompt),
          ),
        );
  }
}

typedef _Cat = ({
  String id,
  String label,
  bool isSeasonal,
  int? startMonth,
  int? startDay,
  int? endMonth,
  int? endDay,
  String? categoryPrompt,
});

const _defaultJokeCategories = <_Cat>[
  (
    id: 'dad',
    label: 'Dad jokes',
    isSeasonal: false,
    startMonth: null,
    startDay: null,
    endMonth: null,
    endDay: null,
    categoryPrompt: 'Puns, groaners, and classic dad-style humor.',
  ),
  (
    id: 'mom',
    label: 'Mom jokes',
    isSeasonal: false,
    startMonth: null,
    startDay: null,
    endMonth: null,
    endDay: null,
    categoryPrompt: 'Lighthearted jokes celebrating moms and family life.',
  ),
  (
    id: 'animal',
    label: 'Animal jokes',
    isSeasonal: false,
    startMonth: null,
    startDay: null,
    endMonth: null,
    endDay: null,
    categoryPrompt: 'Jokes about pets, wildlife, and silly creatures.',
  ),
  (
    id: 'school',
    label: 'School jokes',
    isSeasonal: false,
    startMonth: null,
    startDay: null,
    endMonth: null,
    endDay: null,
    categoryPrompt: 'Classroom, homework, and student life (all ages).',
  ),
  (
    id: 'work',
    label: 'Work jokes',
    isSeasonal: false,
    startMonth: null,
    startDay: null,
    endMonth: null,
    endDay: null,
    categoryPrompt: 'Office humor and workplace absurdity; keep it workplace-safe.',
  ),
  (
    id: 'christmas',
    label: 'Christmas',
    isSeasonal: true,
    startMonth: 12,
    startDay: 1,
    endMonth: 1,
    endDay: 6,
    categoryPrompt:
        'Holiday cheer, winter, gifts, and Santa (avoid religious insult).',
  ),
  (
    id: 'easter',
    label: 'Easter',
    isSeasonal: true,
    startMonth: 3,
    startDay: 1,
    endMonth: 4,
    endDay: 30,
    categoryPrompt: 'Spring, bunnies, eggs, and light seasonal humor.',
  ),
  (
    id: 'halloween',
    label: 'Halloween',
    isSeasonal: true,
    startMonth: 10,
    startDay: 1,
    endMonth: 10,
    endDay: 31,
    categoryPrompt: 'Spooky-but-family-friendly; no gore.',
  ),
  (
    id: 'thanksgiving',
    label: 'Thanksgiving',
    isSeasonal: true,
    startMonth: 11,
    startDay: 1,
    endMonth: 11,
    endDay: 30,
    categoryPrompt: 'Gratitude, feasts, and fall gatherings (U.S.-style).',
  ),
];
