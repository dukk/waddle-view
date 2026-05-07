import 'package:drift/drift.dart';

import '../../persistence/database.dart';

/// Idempotent default trivia categories (edit rows in DB to tune seasons).
Future<void> ensureDefaultTriviaCategories(AppDatabase db) async {
  for (final c in _defaultTriviaCategories) {
    final existing =
        await (db.select(db.triviaCategories)..where((t) => t.id.equals(c.id)))
            .getSingleOrNull();
    if (existing != null) {
      continue;
    }
    await db.into(db.triviaCategories).insert(
          TriviaCategoriesCompanion.insert(
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

typedef _TCat = ({
  String id,
  String label,
  bool isSeasonal,
  int? startMonth,
  int? startDay,
  int? endMonth,
  int? endDay,
  String? categoryPrompt,
});

const _defaultTriviaCategories = <_TCat>[
  (
    id: 'elem_math',
    label: 'Elementary math',
    isSeasonal: false,
    startMonth: null,
    startDay: null,
    endMonth: null,
    endDay: null,
    categoryPrompt:
        'Arithmetic, fractions, shapes, and number sense for grade-school level.',
  ),
  (
    id: 'world_geo',
    label: 'World geography',
    isSeasonal: false,
    startMonth: null,
    startDay: null,
    endMonth: null,
    endDay: null,
    categoryPrompt: 'Countries, capitals, landmarks, rivers, and continents.',
  ),
  (
    id: 'pop_culture',
    label: 'Pop culture',
    isSeasonal: false,
    startMonth: null,
    startDay: null,
    endMonth: null,
    endDay: null,
    categoryPrompt: 'Music, TV, trends, and widely known public figures.',
  ),
  (
    id: 'movies',
    label: 'Movies',
    isSeasonal: false,
    startMonth: null,
    startDay: null,
    endMonth: null,
    endDay: null,
    categoryPrompt: 'Film titles, actors, directors, and famous quotes.',
  ),
  (
    id: 'celebrities',
    label: 'Celebrities',
    isSeasonal: false,
    startMonth: null,
    startDay: null,
    endMonth: null,
    endDay: null,
    categoryPrompt: 'Well-known entertainers and public figures (keep it light).',
  ),
  (
    id: 'technology',
    label: 'Technology',
    isSeasonal: false,
    startMonth: null,
    startDay: null,
    endMonth: null,
    endDay: null,
    categoryPrompt: 'Computers, the internet, gadgets, and famous tech history.',
  ),
  (
    id: 'science',
    label: 'Science',
    isSeasonal: false,
    startMonth: null,
    startDay: null,
    endMonth: null,
    endDay: null,
    categoryPrompt: 'Biology, chemistry, physics, and space at general-audience level.',
  ),
  (
    id: 'sports',
    label: 'Sports',
    isSeasonal: false,
    startMonth: null,
    startDay: null,
    endMonth: null,
    endDay: null,
    categoryPrompt: 'Major sports, rules, records, and famous teams or athletes.',
  ),
  (
    id: 'history',
    label: 'History',
    isSeasonal: false,
    startMonth: null,
    startDay: null,
    endMonth: null,
    endDay: null,
    categoryPrompt: 'World and U.S. history facts; avoid graphic war detail.',
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
        'Family-friendly holiday trivia about traditions, winter, and seasonal customs.',
  ),
  (
    id: 'easter',
    label: 'Easter',
    isSeasonal: true,
    startMonth: 3,
    startDay: 1,
    endMonth: 4,
    endDay: 30,
    categoryPrompt:
        'Springtime and Easter-themed trivia with eggs, bunnies, and celebrations.',
  ),
  (
    id: 'halloween',
    label: 'Halloween',
    isSeasonal: true,
    startMonth: 10,
    startDay: 1,
    endMonth: 10,
    endDay: 31,
    categoryPrompt:
        'Spooky-but-kid-safe trivia about costumes, autumn traditions, and fun facts.',
  ),
  (
    id: 'thanksgiving',
    label: 'Thanksgiving',
    isSeasonal: true,
    startMonth: 11,
    startDay: 1,
    endMonth: 11,
    endDay: 30,
    categoryPrompt:
        'Thanksgiving trivia focused on harvest themes, food traditions, and gratitude.',
  ),
];
