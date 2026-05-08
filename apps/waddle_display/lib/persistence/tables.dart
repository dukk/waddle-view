import 'package:drift/drift.dart';

class ProviderSettings extends Table {
  TextColumn get id => text()();
  TextColumn get providerType => text()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  IntColumn get pollSeconds => integer().withDefault(const Constant(60))();
  TextColumn get baseUrl => text().nullable()();
  TextColumn get configJson => text().nullable()();
  TextColumn get configJsonSchema => text().nullable()();
  TextColumn get exampleConfigJson => text().nullable()();

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
  /// Native pixel dimensions when known (e.g. Pexels API, OneDrive `image` facet).
  IntColumn get pixelWidth => integer().nullable()();
  IntColumn get pixelHeight => integer().nullable()();

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
/// When true, RSS screens only curate articles that have a downloaded image;
/// photo-less articles remain ticker-only unless min-placement fallback applies.
const String kRequireNewsPhotoForScreensKvKey =
    'curator.news.screens.require_photo';
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

/// TV display screen definition (single widget type + config + scheduling hints).
/// Runtime layout JSON for the curator is synthesized when mapping rows to slides.
class ScreenDefinitions extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  /// Widget `type` string (e.g. `weather`, `rss_article`); see `kScreenLayoutWidgetTypes`.
  TextColumn get screenType => text()();
  /// JSON object: former `widgets[0].config` in legacy `layout_json`.
  TextColumn get configJson => text().withDefault(const Constant('{}'))();
  TextColumn get configJsonSchema => text().nullable()();
  TextColumn get exampleConfigJson => text().nullable()();
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

/// Bottom ticker slot: which [tickerType] runs, how often ([frequencyWeight]),
/// and display order ([sortOrder]). [configKey] binds `custom` rows to a
/// `ticker.marquee.*` key; when null, all extra marquee keys are included.
class TickerDefinitions extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  /// One of: `time`, `weather`, `news`, `quote`, `stocks`, `custom`.
  TextColumn get tickerType => text()();
  IntColumn get frequencyWeight => integer().withDefault(const Constant(100))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get configKey => text().nullable()();

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
  /// When true, excluded from slides and news ticker; row kept for stable ids.
  BoolColumn get suppressed => boolean().withDefault(const Constant(false))();

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
  /// When true, excluded from slides; row kept for stable ids.
  BoolColumn get suppressed => boolean().withDefault(const Constant(false))();

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
  /// When true, excluded from slides; row kept for stable ids.
  BoolColumn get suppressed => boolean().withDefault(const Constant(false))();

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
  /// Shared meeting id across calendars (Graph `iCalUId`, Google `iCalUID`) for deduplication.
  TextColumn get icalUid => text().nullable()();
  /// Optional [ContentCategories.id] for dashboard icons / grouping.
  TextColumn get categoryId => text().nullable().references(ContentCategories, #id)();
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

/// Active NWS (api.weather.gov) alerts for a [WeatherLocations] row, keyed by CAP id.
@TableIndex(
  name: 'idx_weather_gov_active_alerts_location',
  columns: {#locationId},
)
class WeatherGovActiveAlerts extends Table {
  TextColumn get locationId => text().references(WeatherLocations, #id)();
  TextColumn get nwsAlertId => text()();
  TextColumn get event => text()();
  TextColumn get headline => text().nullable()();
  TextColumn get severity => text().nullable()();
  DateTimeColumn get effectiveAt => dateTime().nullable()();
  DateTimeColumn get expiresAt => dateTime().nullable()();
  /// Truncated product text for the weather slide (not full CAP description).
  TextColumn get descriptionExcerpt => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {locationId, nwsAlertId};
}

/// Matches [ProviderSettings.id] for media sourced from that provider (e.g. `pexels`).
const String kMediaDataProviderPexels = 'pexels';

/// Microsoft Graph OneDrive sync into [Photos] / [Videos].
const String kMediaDataProviderOneDrive = 'onedrive_media';

/// Flickr group photo sync into [Photos].
const String kMediaDataProviderFlickr = 'flickr_media';

/// Bing homepage image of the day into [Photos].
const String kMediaDataProviderBing = 'bing_iotd';

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
  /// When true, excluded from slides; row kept for stable ids.
  BoolColumn get suppressed => boolean().withDefault(const Constant(false))();

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
  /// When true, excluded from slides; row kept for stable ids.
  BoolColumn get suppressed => boolean().withDefault(const Constant(false))();

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

/// User-configurable list of ticker symbols collected by the `stocks` provider.
/// Mirrors the [WeatherLocations] pattern: rows can be enabled/disabled per
/// symbol and the provider falls back to the seeded `defaultSymbols` from
/// [ProviderSettings.configJson] when no rows are enabled.
class StockSymbols extends Table {
  TextColumn get id => text()();
  TextColumn get symbol => text()();
  TextColumn get displayName => text().withDefault(const Constant(''))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Latest current quote per [StockSymbols.id], written by `StockQuoteDataProvider`.
/// One row per symbol; provider does an `insertOnConflictUpdate` per collect tick.
@TableIndex(
  name: 'idx_stock_quotes_observed',
  columns: {#observedAtMs},
)
class StockQuotes extends Table {
  TextColumn get symbolId => text().references(StockSymbols, #id)();
  RealColumn get currentPrice => real().nullable()();
  RealColumn get changeAmount => real().nullable()();
  RealColumn get percentChange => real().nullable()();
  RealColumn get highOfDay => real().nullable()();
  RealColumn get lowOfDay => real().nullable()();
  RealColumn get openPrice => real().nullable()();
  RealColumn get previousClose => real().nullable()();
  DateTimeColumn get quotedAtMs => dateTime().nullable()();
  DateTimeColumn get observedAtMs => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {symbolId};
}
