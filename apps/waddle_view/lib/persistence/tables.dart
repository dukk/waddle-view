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
  DateTimeColumn get capturedAt => dateTime()();

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
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get expiresAt => dateTime().nullable()();
  DateTimeColumn get dismissedAt => dateTime().nullable()();
  TextColumn get source => text().withDefault(const Constant('api'))();
}

/// App configuration and dashboard key–value settings (table `config_key_values`).
class ConfigKeyValues extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

const String kCuratorProgramDurationSecondsKvKey =
    'curator.program.durationSeconds';
const String kCuratorHistoryDepthKvKey = 'curator.program.historyDepth';
const String kAdminBootstrapDoneKvKey = 'admin.bootstrap_done';

/// Shared category ids for RSS feeds, Pexels photos/videos, jokes, and trivia
/// ([RssFeedSources.category], [Photos.category], [Videos.category], and category
/// ids on [JokeCategories] / [TriviaCategories] use the same string keys).
///
/// Icon: set [materialIconName] (resolved in app code) and/or [iconBlobKey] for a
/// custom image in blob storage.
class ContentCategories extends Table {
  TextColumn get id => text()();
  TextColumn get label => text()();
  TextColumn get iconBlobKey => text().nullable()();
  TextColumn get materialIconName => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// TV display screen definition (layout + scheduling hints). Runtime curation is in memory.
class ScreenDefinitions extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  TextColumn get layoutJson =>
      text().withDefault(const Constant('{"v":1,"layout":"single","widgets":[]}'))();
  IntColumn get dwellSeconds => integer().withDefault(const Constant(10))();
  IntColumn get frequencyWeight => integer().withDefault(const Constant(100))();
  IntColumn get minGapBetweenShowsSeconds =>
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

class RssFeedSources extends Table {
  TextColumn get id => text()();
  TextColumn get url => text()();
  /// Slug matching [ContentCategories.id] (seeded in [ContentCategories]).
  TextColumn get category => text().withDefault(const Constant('general'))();
  IntColumn get pollSeconds =>
      integer().withDefault(const Constant(3600))();
  IntColumn get maxArticles => integer().withDefault(const Constant(3))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastFetchedAt => dateTime().nullable()();
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
  DateTimeColumn get publishedAt => dateTime()();
  DateTimeColumn get fetchedAt => dateTime()();
  TextColumn get imageBlobKey => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class JokeCategories extends Table {
  /// Same string as [ContentCategories.id] for icon/label sharing.
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
  DateTimeColumn get requestedAtMs => dateTime()();
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
  DateTimeColumn get createdAtMs => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class TriviaCategories extends Table {
  /// Same string as [ContentCategories.id] for icon/label sharing.
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
  DateTimeColumn get requestedAtMs => dateTime()();
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
  DateTimeColumn get createdAtMs => dateTime()();

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
  DateTimeColumn get startMs => dateTime()();
  DateTimeColumn get endMs => dateTime()();
  BoolColumn get allDay => boolean().withDefault(const Constant(false))();
  TextColumn get location => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get source => text().withDefault(const Constant('local'))();
  TextColumn get externalId => text().nullable()();
  DateTimeColumn get updatedAtMs => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class WeatherLocations extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(
  name: 'idx_weather_current_data_observed',
  columns: {#observedAtMs},
)
class WeatherCurrentData extends Table {
  TextColumn get locationId => text().references(WeatherLocations, #id)();
  DateTimeColumn get observedAtMs => dateTime()();
  RealColumn get currentTemp => real().nullable()();
  TextColumn get currentDescription => text().nullable()();
  TextColumn get currentIconBlobKey => text().nullable()();
  TextColumn get hourlyJson => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {locationId};
}

/// Matches [ProviderSettings.id] for media sourced from that provider (e.g. `pexels`).
const String kMediaDataProviderPexels = 'pexels';

@TableIndex(
  name: 'idx_photos_fetched',
  columns: {#fetchedAtMs},
)
@TableIndex(
  name: 'idx_photos_category',
  columns: {#category},
)
class Photos extends Table {
  TextColumn get id => text()();
  /// Slug matching [ContentCategories.id] (default `pexels`).
  TextColumn get category => text().withDefault(const Constant('pexels'))();
  TextColumn get dataProvider =>
      text().withDefault(const Constant(kMediaDataProviderPexels))();
  TextColumn get mediaBlobKey => text()();
  TextColumn get photographerName => text()();
  TextColumn get photographerUrl => text()();
  TextColumn get pexelsPageUrl => text()();
  TextColumn get altText => text().withDefault(const Constant(''))();
  DateTimeColumn get fetchedAtMs => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(
  name: 'idx_videos_fetched',
  columns: {#fetchedAtMs},
)
@TableIndex(
  name: 'idx_videos_category',
  columns: {#category},
)
class Videos extends Table {
  TextColumn get id => text()();
  /// Slug matching [ContentCategories.id] (default `pexels`).
  TextColumn get category => text().withDefault(const Constant('pexels'))();
  TextColumn get dataProvider =>
      text().withDefault(const Constant(kMediaDataProviderPexels))();
  TextColumn get mediaBlobKey => text()();
  TextColumn get photographerName => text()();
  TextColumn get photographerUrl => text()();
  TextColumn get pexelsPageUrl => text()();
  TextColumn get altText => text().withDefault(const Constant(''))();
  IntColumn get durationSeconds => integer()();
  DateTimeColumn get fetchedAtMs => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(
  name: 'idx_pexels_fetch_batches_time',
  columns: {#requestedAtMs},
)
class PexelsFetchBatches extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get requestedAtMs => dateTime()();
  TextColumn get kind => text()();
  IntColumn get count => integer().withDefault(const Constant(1))();
}
