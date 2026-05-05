import 'package:drift/drift.dart';

class ProviderSettings extends Table {
  TextColumn get id => text()();
  TextColumn get providerType => text()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  IntColumn get pollSeconds => integer().withDefault(const Constant(60))();
  TextColumn get baseUrl => text().nullable()();
  TextColumn get extraJson => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class BlobMetadata extends Table {
  TextColumn get blobKey => text()();
  TextColumn get sha256 => text()();
  TextColumn get relativePath => text()();
  IntColumn get bytes => integer()();
  TextColumn get mimeType => text().nullable()();
  IntColumn get capturedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {blobKey};
}

class DashboardAlerts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get body => text()();
  TextColumn get qrPayload => text().nullable()();
  TextColumn get severity => text().withDefault(const Constant('info'))();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get expiresAt => integer().nullable()();
  IntColumn get dismissedAt => integer().nullable()();
  TextColumn get source => text().withDefault(const Constant('api'))();
}

class DashboardKv extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// TV display screen definition (layout + scheduling hints). Runtime curation is in memory.
class ScreenDefinitions extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  TextColumn get layoutJson =>
      text().withDefault(const Constant('{"v":1,"layout":"single","widgets":[]}'))();
  IntColumn get dwellMs => integer().withDefault(const Constant(10000))();
  IntColumn get frequencyWeight => integer().withDefault(const Constant(100))();
  IntColumn get minGapBetweenShowsMs =>
      integer().withDefault(const Constant(0))();
  IntColumn get minPlacementsPerProgram =>
      integer().withDefault(const Constant(0))();
  IntColumn get maxPlacementsPerProgram => integer().nullable()();
  TextColumn get dataKey => text().withDefault(const Constant(''))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Aggregate min/max placements per program for all screens sharing [dataKey].
class CuratorDataKeyProgramLimits extends Table {
  TextColumn get dataKey => text()();
  IntColumn get minPlacementsPerProgram =>
      integer().withDefault(const Constant(0))();
  IntColumn get maxPlacementsPerProgram => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {dataKey};
}

/// Single app row (id = [kCuratorSettingsId]) for screen program parameters.
class CuratorSettings extends Table {
  TextColumn get id => text()();
  IntColumn get programDurationMs =>
      integer().withDefault(const Constant(180000))();
  IntColumn get historyDepth => integer().withDefault(const Constant(5))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

const String kCuratorSettingsId = 'app';

class RssFeedSources extends Table {
  TextColumn get id => text()();
  TextColumn get url => text()();
  TextColumn get category => text().withDefault(const Constant('general'))();
  IntColumn get pollSeconds =>
      integer().withDefault(const Constant(3600))();
  IntColumn get maxArticles => integer().withDefault(const Constant(3))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  IntColumn get lastFetchedAt => integer().nullable()();
  TextColumn get title => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(
  name: 'idx_rss_articles_by_feed',
  columns: {#feedId, #publishedAt},
)
class RssArticles extends Table {
  TextColumn get id => text()();
  TextColumn get feedId => text().references(RssFeedSources, #id)();
  TextColumn get guid => text()();
  TextColumn get title => text()();
  TextColumn get link => text()();
  TextColumn get summary => text().nullable()();
  IntColumn get publishedAt => integer()();
  IntColumn get fetchedAt => integer()();
  TextColumn get imageBlobKey => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class JokeCategories extends Table {
  TextColumn get id => text()();
  TextColumn get label => text()();
  BoolColumn get isSeasonal => boolean().withDefault(const Constant(false))();
  IntColumn get startMonth => integer().nullable()();
  IntColumn get startDay => integer().nullable()();
  IntColumn get endMonth => integer().nullable()();
  IntColumn get endDay => integer().nullable()();
  TextColumn get categoryPrompt => text().nullable()();
  IntColumn get minJokes =>
      integer().withDefault(const Constant(10))();
  IntColumn get maxJokes =>
      integer().withDefault(const Constant(100))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Records each OpenAI joke-generation request size for rolling-window rate limits.
@TableIndex(
  name: 'idx_joke_gen_batches_by_time',
  columns: {#requestedAtMs},
)
class JokeGenerationBatches extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get requestedAtMs => integer()();
  IntColumn get jokesRequested => integer()();
}

@TableIndex(
  name: 'idx_jokes_by_created_at',
  columns: {#createdAtMs},
)
@TableIndex(
  name: 'idx_jokes_by_category',
  columns: {#categoryId},
)
class Jokes extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text().references(JokeCategories, #id)();
  TextColumn get setup => text()();
  TextColumn get punchline => text()();
  IntColumn get createdAtMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class TriviaCategories extends Table {
  TextColumn get id => text()();
  TextColumn get label => text()();
  BoolColumn get isSeasonal => boolean().withDefault(const Constant(false))();
  IntColumn get startMonth => integer().nullable()();
  IntColumn get startDay => integer().nullable()();
  IntColumn get endMonth => integer().nullable()();
  IntColumn get endDay => integer().nullable()();
  TextColumn get categoryPrompt => text().nullable()();
  IntColumn get minQuestions =>
      integer().withDefault(const Constant(10))();
  IntColumn get maxQuestions =>
      integer().withDefault(const Constant(100))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Records each OpenAI trivia-generation request size for rolling-window rate limits.
@TableIndex(
  name: 'idx_trivia_gen_batches_by_time',
  columns: {#requestedAtMs},
)
class TriviaGenerationBatches extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get requestedAtMs => integer()();
  IntColumn get questionsRequested => integer()();
}

@TableIndex(
  name: 'idx_trivia_questions_by_created_at',
  columns: {#createdAtMs},
)
@TableIndex(
  name: 'idx_trivia_questions_by_category',
  columns: {#categoryId},
)
class TriviaQuestions extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text().references(TriviaCategories, #id)();
  TextColumn get question => text()();
  TextColumn get optionA => text()();
  TextColumn get optionB => text()();
  TextColumn get optionC => text()();
  TextColumn get optionD => text()();
  TextColumn get correctOption => text()();
  IntColumn get createdAtMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Local and synced calendar events (Outlook / Google providers later).
@TableIndex(
  name: 'idx_calendar_events_start_ms',
  columns: {#startMs},
)
class CalendarEvents extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  IntColumn get startMs => integer()();
  IntColumn get endMs => integer()();
  BoolColumn get allDay => boolean().withDefault(const Constant(false))();
  TextColumn get location => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get source => text().withDefault(const Constant('local'))();
  TextColumn get externalId => text().nullable()();
  IntColumn get updatedAtMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
