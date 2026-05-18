import 'package:drift/drift.dart';

export '../news/news_source_types.dart';

/// Operator-configured integrations (collectors); persisted as SQLite `integrations`.
class Integrations extends Table {
  TextColumn get id => text()();
  TextColumn get integrationType => text()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  IntColumn get pollSeconds => integer().withDefault(const Constant(60))();
  TextColumn get baseUrl => text().nullable()();
  TextColumn get configJson => text().nullable()();
  TextColumn get configJsonSchema => text().nullable()();
  TextColumn get exampleConfigJson => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Shared sign-in identities (Google, Microsoft, API keys) used by integrations.
class IntegrationAccounts extends Table {
  TextColumn get id => text()();
  TextColumn get accountType => text()();
  TextColumn get label => text().nullable()();
  IntColumn get createdAtMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Links an [Integrations] row to one or more [IntegrationAccounts].
class IntegrationAccountLinks extends Table {
  TextColumn get integrationId =>
      text().references(Integrations, #id, onDelete: KeyAction.cascade)();
  TextColumn get accountId =>
      text().references(IntegrationAccounts, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column<Object>> get primaryKey => {integrationId, accountId};
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

/// Operator-visible alerts (OAuth device codes, manual notices). SQLite `alerts`.
@DataClassName('DashboardAlert')
class Alerts extends Table {
  @override
  String get tableName => 'alerts';

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

/// Curator configuration layer: exclusive replaces all; base drives program;
/// enhancement stacks overlay members on base.
const String kCuratorLayerExclusive = 'exclusive';
const String kCuratorLayerBase = 'base';
const String kCuratorLayerEnhancement = 'enhancement';

const List<String> kCuratorConfigurationLayers = [
  kCuratorLayerExclusive,
  kCuratorLayerBase,
  kCuratorLayerEnhancement,
];

/// [CuratorConfigurationMembers.entityType] values.
const String kCuratorMemberEntityScreen = 'screen';
const String kCuratorMemberEntityTicker = 'ticker';
const String kCuratorMemberEntityOverlay = 'overlay';

const List<String> kCuratorMemberEntityTypes = [
  kCuratorMemberEntityScreen,
  kCuratorMemberEntityTicker,
  kCuratorMemberEntityOverlay,
];
const String kAdminBootstrapDoneKvKey = 'admin.bootstrap_done';

/// Global kill-switch for festive display overlays (`'true'` / `'false'`). Absent = enabled.
const String kDisplayOverlayEnabledKvKey = 'display.overlay.enabled';

/// IANA time zone id for calendar wall-clock display (e.g. `America/Chicago`).
/// [ConfigKeyValues] value; invalid or empty values fall back to [kDefaultDisplayTimezoneIana].
const String kDisplayTimezoneKvKey = 'display.timezone';

/// Default [kDisplayTimezoneKvKey] on first seed (US Eastern, observes DST).
const String kDefaultDisplayTimezoneIana = 'America/New_York';

/// Plugin screen widget `type` ([Screens.screenType]).
const String kScreenTypePluginTemplate = 'plugin_template';

/// Plugin HTTP collector ([Integrations.integrationType]).
const String kProviderTypePluginHttp = 'plugin_http';

/// Plugin ticker tape ([TickerTapes.tickerType]).
const String kTickerTypePlugin = 'plugin';

/// Celebration overlay renderer for plugin template layers.
const String kOverlayRendererPluginTemplate = 'plugin_template';

/// Celebration overlay renderer for plugin WebView layers.
const String kOverlayRendererPluginWeb = 'plugin_web';

/// Overlay type stored in `overlays.overlay_type` (semantic id, like `screen_type`).
const String kOverlayTypeHeartsRain = 'hearts_rain';

/// Subtle falling confetti + optional sparse messages.
const String kOverlayTypeBirthdayConfetti = 'birthday_confetti';

/// Single phrase bouncing off screen edges (DVD-style).
const String kOverlayTypeBouncingMessage = 'bouncing_message';

/// Seed row id for the example May 13 bouncing message overlay (installed disabled).
const String kDefaultBouncingMessageOverlayId = 'default_bouncing_message_may_13';

/// Default phrase for [kOverlayTypeBouncingMessage] when `config_json.messages` is empty.
const String kDefaultBouncingMessageOverlayPhrase = 'Happy Birthday Waddle!!';

/// Seed row id for the US Mother's Day `[overlays]` preset.
const String kDefaultMothersDayOverlayId = 'default_mothers_day_us';

/// Seed row id for the example May 13 birthday confetti overlay (installed disabled).
const String kDefaultBirthdayOverlayExampleId = 'default_birthday_example_may_13';

/// Shared category ids for RSS feeds, Pexels photos/videos, jokes, and trivia
/// ([InterestsRssFeeds.category], [Photos.category], [Videos.category], and category
/// ids on [InterestsJokes] / [InterestsTrivia] use the same string keys).
///
/// Icon: set [materialIconName] (resolved in app code) and/or [iconBlobKey] for a
/// custom image in blob storage.
///
/// Persisted as SQLite `curator_categories` (renamed from `content_categories`).
class ContentCategories extends Table {
  @override
  String get tableName => 'curator_categories';
  TextColumn get id => text()();
  TextColumn get label => text()();
  TextColumn get iconBlobKey => text().nullable()();
  TextColumn get materialIconName => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// TV display screen definition (single widget type + config + scheduling hints).
/// Runtime layout JSON for the curator is synthesized when mapping rows to slides.
/// SQLite `screens` (legacy name `screen_definitions`).
@DataClassName('ScreenDefinition')
class Screens extends Table {
  @override
  String get tableName => 'screens';

  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().withDefault(const Constant(''))();

  /// Widget `type` string (e.g. `weather`, `news`); see `kScreenLayoutWidgetTypes`.
  TextColumn get screenType => text()();

  /// JSON object: former `widgets[0].config` in legacy `layout_json`.
  TextColumn get configJson => text().withDefault(const Constant('{}'))();
  TextColumn get configJsonSchema => text().nullable()();
  TextColumn get exampleConfigJson => text().nullable()();
  IntColumn get minDwellSeconds => integer().withDefault(const Constant(8))();
  IntColumn get maxDwellSeconds => integer().withDefault(const Constant(15))();
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

/// Bottom ticker tape: which [tickerType] runs, how often ([frequencyWeight]),
/// and display order ([sortOrder]). [configJson] holds per-tape options (for
/// example [fallbackText] for weather/news/quote). [configKey] binds `custom`
/// rows to a `ticker.marquee.*` key in [ConfigKeyValues]; when null, all
/// `ticker.marquee.*` keys are included for that tape.
///
/// Backed by the SQLite table `ticker_tapes` (formerly `ticker_definitions`).
class TickerTapes extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().withDefault(const Constant(''))();

  /// One of: `time`, `weather`, `news`, `quote`, `stocks`, `custom`.
  TextColumn get tickerType => text()();
  IntColumn get frequencyWeight => integer().withDefault(const Constant(100))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get configKey => text().nullable()();

  /// Slot JSON (e.g. `fallbackText` when live/RSS data is missing for weather/news/quote).
  TextColumn get configJson => text().withDefault(const Constant('{}'))();

  /// JSON Schema (draft 2020-12) describing marquee / KV options for [tickerType].
  TextColumn get configJsonSchema => text().nullable()();

  /// Example JSON for the same documentation shape as [configJsonSchema].
  TextColumn get exampleConfigJson => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Operator-defined curator program (screens/ticker/overlays membership + tuning).
class CuratorConfigurations extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get layer => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get programDurationSeconds =>
      integer().withDefault(const Constant(180))();
  IntColumn get historyDepth => integer().withDefault(const Constant(5))();
  BoolColumn get requireNewsPhotoForScreens =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get tickerEnabled => boolean().withDefault(const Constant(true))();
  TextColumn get themeIdOverride => text().nullable()();
  BoolColumn get defaultConfig => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// When a configuration is active (calendar, time, and/or runtime state).
class CuratorScheduleRules extends Table {
  TextColumn get id => text()();
  TextColumn get configurationId => text()();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  TextColumn get statePredicate => text().nullable()();
  IntColumn get daysOfWeekMask => integer().nullable()();
  IntColumn get startTimeMinutes => integer().nullable()();
  IntColumn get endTimeMinutes => integer().nullable()();
  IntColumn get startMonth => integer().nullable()();
  IntColumn get startDay => integer().nullable()();
  IntColumn get endMonth => integer().nullable()();
  IntColumn get endDay => integer().nullable()();
  BoolColumn get repeatAnnually =>
      boolean().withDefault(const Constant(true))();
  IntColumn get yearExact => integer().nullable()();
  IntColumn get nthWeekOfMonth => integer().nullable()();
  IntColumn get nthWeekday => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Catalog entity ids enabled while a [CuratorConfigurations] row is active.
class CuratorConfigurationMembers extends Table {
  TextColumn get configurationId => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();

  @override
  Set<Column<Object>> get primaryKey => {configurationId, entityType, entityId};
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

/// Max consecutive download failures before [InterestsRssFeeds.enabled] is forced
/// to `false`. Reset to 0 on any successful collect.
const int kRssMaxConsecutiveFailures = 5;

/// Upper bound on the exponential per-feed retry backoff (24h). Prevents
/// arbitrarily large `[InterestsRssFeeds.pollSeconds] * 2^(n-1)` values from
/// pushing `nextRetryAt` past sensible operator-visible windows.
const int kRssMaxRetryBackoffSeconds = 86400;

/// Operator-configured RSS feed sources (SQLite `interests_rss_feeds`).
class InterestsRssFeeds extends Table {
  @override
  String get tableName => 'interests_rss_feeds';

  TextColumn get id => text()();
  TextColumn get url => text()();

  /// Slug matching [ContentCategories.id] (seeded in [ContentCategories]).
  TextColumn get category => text().withDefault(const Constant('general'))();
  IntColumn get pollSeconds => integer().withDefault(const Constant(3600))();
  IntColumn get maxArticles => integer().withDefault(const Constant(3))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastFetchedAt => dateTime().nullable()();
  TextColumn get title => text().nullable()();

  /// Number of back-to-back failed downloads (HTTP non-200, network throw, or
  /// parse error). Reset to 0 on each successful collect. The RSS provider
  /// forces [enabled] to `false` once this reaches [kRssMaxConsecutiveFailures].
  IntColumn get consecutiveFailures =>
      integer().withDefault(const Constant(0))();

  /// Earliest wall-clock time the RSS provider may retry this feed after a
  /// failure. `null` means no active backoff (use [pollSeconds] instead).
  DateTimeColumn get nextRetryAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Unified news articles (RSS + social). SQLite `news` (legacy `rss_articles`).
@TableIndex(
  name: 'idx_news_by_source',
  columns: {#sourceType, #sourceId, #publishedAt},
)
@DataClassName('NewsArticle')
class News extends Table {
  @override
  String get tableName => 'news';

  TextColumn get id => text()();
  TextColumn get sourceType => text()();
  TextColumn get sourceId => text()();
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

/// Operator-configured Facebook page/group sources (SQLite `interests_facebook_sources`).
class InterestsFacebookSources extends Table {
  @override
  String get tableName => 'interests_facebook_sources';

  TextColumn get id => text()();
  TextColumn get targetType => text()();
  TextColumn get targetId => text()();
  TextColumn get accountId => text()();
  IntColumn get pollSeconds => integer().withDefault(const Constant(3600))();
  IntColumn get maxArticles => integer().withDefault(const Constant(3))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastFetchedAt => dateTime().nullable()();
  TextColumn get title => text().nullable()();
  IntColumn get consecutiveFailures =>
      integer().withDefault(const Constant(0))();
  DateTimeColumn get nextRetryAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Operator-configured X (Twitter) user sources (SQLite `interests_twitter_sources`).
class InterestsTwitterSources extends Table {
  @override
  String get tableName => 'interests_twitter_sources';

  TextColumn get id => text()();
  TextColumn get targetType => text()();
  TextColumn get targetId => text()();
  TextColumn get accountId => text()();
  IntColumn get pollSeconds => integer().withDefault(const Constant(3600))();
  IntColumn get maxArticles => integer().withDefault(const Constant(3))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastFetchedAt => dateTime().nullable()();
  TextColumn get title => text().nullable()();
  IntColumn get consecutiveFailures =>
      integer().withDefault(const Constant(0))();
  DateTimeColumn get nextRetryAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Operator-configured LinkedIn sources (SQLite `interests_linkedin_sources`).
class InterestsLinkedinSources extends Table {
  @override
  String get tableName => 'interests_linkedin_sources';

  TextColumn get id => text()();
  TextColumn get targetType => text()();
  TextColumn get targetId => text()();
  TextColumn get accountId => text()();
  IntColumn get pollSeconds => integer().withDefault(const Constant(3600))();
  IntColumn get maxArticles => integer().withDefault(const Constant(3))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastFetchedAt => dateTime().nullable()();
  TextColumn get title => text().nullable()();
  IntColumn get consecutiveFailures =>
      integer().withDefault(const Constant(0))();
  DateTimeColumn get nextRetryAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Operator-configured joke categories (SQLite `interests_jokes`).
class InterestsJokes extends Table {
  @override
  String get tableName => 'interests_jokes';

  /// Same string as [ContentCategories.id] for icon/label sharing.
  TextColumn get id => text()();
  TextColumn get label => text()();
  BoolColumn get isSeasonal => boolean().withDefault(const Constant(false))();
  IntColumn get startMonth => integer().nullable()();
  IntColumn get startDay => integer().nullable()();
  IntColumn get endMonth => integer().nullable()();
  IntColumn get endDay => integer().nullable()();
  TextColumn get categoryPrompt => text().nullable()();
  IntColumn get minJokes => integer().withDefault(const Constant(10))();
  IntColumn get maxJokes => integer().withDefault(const Constant(100))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Records each OpenAI joke-generation request size for rolling-window rate limits.
@TableIndex(name: 'idx_joke_gen_batches_by_time', columns: {#requestedAtMs})
class JokeGenerationBatches extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get requestedAtMs => dateTime()();
  IntColumn get jokesRequested => integer()();
}

@TableIndex(name: 'idx_jokes_by_created_at', columns: {#createdAtMs})
@TableIndex(name: 'idx_jokes_by_category', columns: {#categoryId})
class Jokes extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text().references(InterestsJokes, #id)();
  TextColumn get setup => text()();
  TextColumn get punchline => text()();
  DateTimeColumn get createdAtMs => dateTime()();

  /// When true, excluded from slides; row kept for stable ids.
  BoolColumn get suppressed => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Operator-configured trivia categories (SQLite `interests_trivia`).
class InterestsTrivia extends Table {
  @override
  String get tableName => 'interests_trivia';

  /// Same string as [ContentCategories.id] for icon/label sharing.
  TextColumn get id => text()();
  TextColumn get label => text()();
  BoolColumn get isSeasonal => boolean().withDefault(const Constant(false))();
  IntColumn get startMonth => integer().nullable()();
  IntColumn get startDay => integer().nullable()();
  IntColumn get endMonth => integer().nullable()();
  IntColumn get endDay => integer().nullable()();
  TextColumn get categoryPrompt => text().nullable()();
  IntColumn get minQuestions => integer().withDefault(const Constant(10))();
  IntColumn get maxQuestions => integer().withDefault(const Constant(100))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Records each OpenAI trivia-generation request size for rolling-window rate limits.
@TableIndex(name: 'idx_trivia_gen_batches_by_time', columns: {#requestedAtMs})
class TriviaGenerationBatches extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get requestedAtMs => dateTime()();
  IntColumn get questionsRequested => integer()();
}

@TableIndex(name: 'idx_trivia_questions_by_created_at', columns: {#createdAtMs})
@TableIndex(name: 'idx_trivia_questions_by_category', columns: {#categoryId})
class TriviaQuestions extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text().references(InterestsTrivia, #id)();
  TextColumn get question => text()();
  TextColumn get optionA => text()();
  TextColumn get optionB => text()();
  TextColumn get optionC => text()();
  TextColumn get optionD => text()();
  TextColumn get correctOption => text()();
  DateTimeColumn get createdAtMs => dateTime()();

  /// [Integrations.id] for the collector that wrote this row (`trivia_openai`, `trivia_opentdb`).
  TextColumn get integrationId => text().nullable()();

  /// When true, excluded from slides; row kept for stable ids.
  BoolColumn get suppressed => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Local and synced calendar events (Outlook / Google providers later).
@TableIndex(name: 'idx_calendar_events_start_ms', columns: {#startMs})
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
  TextColumn get categoryId =>
      text().nullable().references(ContentCategories, #id)();
  DateTimeColumn get updatedAtMs => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Operator-configured weather locations (SQLite `interests_locations`).
class InterestsLocations extends Table {
  @override
  String get tableName => 'interests_locations';

  TextColumn get id => text()();
  TextColumn get name => text()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  TextColumn get category => text().withDefault(const Constant('general'))();
  BoolColumn get includeWeather => boolean().withDefault(const Constant(false))();
  BoolColumn get includeWeatherAlerts =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get includeLocalNews => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(name: 'idx_weather_current_observed', columns: {#observedAtMs})
@DataClassName('WeatherCurrentData')
class WeatherCurrent extends Table {
  @override
  String get tableName => 'weather_current';

  TextColumn get locationId => text().references(InterestsLocations, #id)();
  DateTimeColumn get observedAtMs => dateTime()();
  RealColumn get currentTemp => real().nullable()();
  TextColumn get currentDescription => text().nullable()();
  TextColumn get currentIconBlobKey => text().nullable()();
  TextColumn get hourlyJson => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {locationId};
}

/// Active NWS (api.weather.gov) alerts for an [InterestsLocations] row, keyed by CAP id.
/// SQLite `weather_alerts` (legacy `weather_gov_active_alerts`).
@TableIndex(
  name: 'idx_weather_alerts_location',
  columns: {#locationId},
)
@DataClassName('WeatherGovActiveAlert')
class WeatherAlerts extends Table {
  @override
  String get tableName => 'weather_alerts';

  TextColumn get locationId => text().references(InterestsLocations, #id)();
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

/// Matches [Integrations.integrationType] for Pexels photo ingest.
const String kMediaDataProviderPhotoPexels = 'photo_pexels';

/// Matches [Integrations.integrationType] for Pexels video ingest.
const String kMediaDataProviderVideoPexels = 'video_pexels';

/// Microsoft Graph OneDrive photo ingest into [Photos].
const String kMediaDataProviderPhotoOneDrive = 'photo_onedrive';

/// Microsoft Graph OneDrive video ingest into [Videos].
const String kMediaDataProviderVideoOneDrive = 'video_onedrive';

/// Flickr group photo sync into [Photos].
const String kMediaDataProviderPhotoFlickr = 'photo_flickr';

/// Bing homepage image of the day into [Photos].
const String kMediaDataProviderPhotoBingIotd = 'photo_bing_image_of_the_day';

@TableIndex(name: 'idx_photos_fetched', columns: {#fetchedAtMs})
@TableIndex(name: 'idx_photos_category', columns: {#category})
class Photos extends Table {
  TextColumn get id => text()();

  /// Slug matching [ContentCategories.id] (default `pexels`).
  TextColumn get category => text().withDefault(const Constant('pexels'))();
  TextColumn get dataProvider =>
      text().withDefault(const Constant(kMediaDataProviderPhotoPexels))();
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

@TableIndex(name: 'idx_videos_fetched', columns: {#fetchedAtMs})
@TableIndex(name: 'idx_videos_category', columns: {#category})
class Videos extends Table {
  TextColumn get id => text()();

  /// Slug matching [ContentCategories.id] (default `pexels`).
  TextColumn get category => text().withDefault(const Constant('pexels'))();
  TextColumn get dataProvider =>
      text().withDefault(const Constant(kMediaDataProviderVideoPexels))();
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

@TableIndex(name: 'idx_pexels_fetch_batches_time', columns: {#requestedAtMs})
class PexelsFetchBatches extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get requestedAtMs => dateTime()();
  TextColumn get kind => text()();
  IntColumn get count => integer().withDefault(const Constant(1))();
}

/// User-configurable list of ticker symbols collected by the `stocks` provider.
/// Mirrors the [InterestsLocations] pattern: rows can be enabled/disabled per
/// symbol and the provider falls back to the seeded `defaultSymbols` from
/// [Integrations.configJson] when no rows are enabled.
class InterestsStockSymbols extends Table {
  @override
  String get tableName => 'interests_stock_symbols';

  TextColumn get id => text()();
  TextColumn get symbol => text()();
  TextColumn get displayName => text().withDefault(const Constant(''))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Operator-curated reject-word list applied by the curator and providers.
///
/// Each row's [action] is one of [kRejectTermActionCensor] or
/// [kRejectTermActionBlock]:
///
/// - `censor` rows cause matching words in news/joke/trivia text to be replaced
///   with a configurable mask (see [kRejectCensorFormatKvKey]) at slide/ticker
///   load time; the underlying DB row is left untouched.
/// - `block` rows mark matching news/joke/trivia rows `suppressed = true` so
///   the curator never schedules them again.
///
/// For [Photos] / [Videos] rows, ANY entry in this table (regardless of
/// [action]) that matches the photographer name, alt text, or any URL field
/// (with `-` and `_` treated as spaces) sets `suppressed = true`. Image
/// content cannot be censored, so media matches always block.
///
/// Persisted as SQLite `curator_rejected_terms` (renamed from `reject_terms`).
class RejectTerms extends Table {
  @override
  String get tableName => 'curator_rejected_terms';
  TextColumn get id => text()();

  /// Lowercased single term. Matched case-insensitively with `\b` word
  /// boundaries against text fields; for URL/media matches the URL is
  /// normalized (lowercase, `-`/`_`/`/`/`?`/`=`/`&`/`.` -> space) first.
  TextColumn get term => text().customConstraint('NOT NULL UNIQUE')();

  /// One of [kRejectTermActionCensor] or [kRejectTermActionBlock]; the
  /// repository validates this on insert/update.
  TextColumn get action => text()();
  IntColumn get createdAtMs => integer()();
  IntColumn get updatedAtMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// [RejectTerms.action] value: replace matches in text content at display time.
const String kRejectTermActionCensor = 'censor';

/// [RejectTerms.action] value: mark matching rows `suppressed = true` so the
/// curator never schedules them.
const String kRejectTermActionBlock = 'block';

/// [ConfigKeyValues.key] holding the operator's preferred censor mask format
/// (one of [kRejectCensorFormatAsterisksFull], [kRejectCensorFormatAsterisksFixed],
/// [kRejectCensorFormatFirstLast], [kRejectCensorFormatBracketedToken]). Missing
/// or unrecognized values fall back to [kRejectCensorFormatAsterisksFull].
const String kRejectCensorFormatKvKey = 'curator.reject.censorFormat';

/// Replace each matched word with asterisks of the same length (`damn` -> `****`).
const String kRejectCensorFormatAsterisksFull = 'asterisks_full';

/// Replace each matched word with a fixed 4-asterisk token regardless of length.
const String kRejectCensorFormatAsterisksFixed = 'asterisks_fixed';

/// Keep the first and last character of the matched word, mask the middle
/// (`damn` -> `d**n`; words of length <=2 fall back to all asterisks).
const String kRejectCensorFormatFirstLast = 'first_last';

/// Replace each matched word with the literal token `[censored]`.
const String kRejectCensorFormatBracketedToken = 'bracketed_token';

/// Latest current quote per [InterestsStockSymbols.id], written by `StockQuoteDataProvider`.
/// One row per symbol; provider does an `insertOnConflictUpdate` per collect tick.
@TableIndex(name: 'idx_stock_quotes_observed', columns: {#observedAtMs})
class StockQuotes extends Table {
  TextColumn get symbolId => text().references(InterestsStockSymbols, #id)();
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

/// Operator-configured Home Assistant entity ids collected by `home_assistant`.
class InterestsHomeAssistantEntities extends Table {
  @override
  String get tableName => 'interests_home_assistant_entities';

  TextColumn get id => text()();
  TextColumn get entityId => text().unique()();
  TextColumn get displayName => text().withDefault(const Constant(''))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Latest state per tracked Home Assistant entity, written by `home_assistant`.
class HomeAssistantEntityStates extends Table {
  TextColumn get entityId =>
      text().references(InterestsHomeAssistantEntities, #entityId)();
  TextColumn get state => text()();
  TextColumn get attributesJson => text()();
  IntColumn get lastUpdatedMs => integer().nullable()();
  IntColumn get observedAtMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {entityId};
}

/// Built-in operator roles for display REST / controller auth.
const String kUserRoleAdmin = 'admin';
const String kUserRoleOperator = 'operator';
const String kUserRolePowerViewer = 'power_viewer';
const String kUserRoleViewer = 'viewer';

/// Short-lived adoption challenge state (REST device flow).
class AdoptionPending extends Table {
  TextColumn get id => text()();
  TextColumn get identifier => text()();
  TextColumn get role => text()();
  IntColumn get issuedAtMs => integer()();
  IntColumn get expiresAtMs => integer()();
  TextColumn get challengeHash => text()();
  TextColumn get nonce => text()();
  IntColumn get alertId => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Adopted REST clients (API key stored as SHA-256 hash only).
class ApiClients extends Table {
  TextColumn get id => text()();
  TextColumn get identifier => text()();
  TextColumn get role => text()();
  TextColumn get apiKeyHash => text()();
  TextColumn get referrerOrigin => text().nullable()();
  IntColumn get createdAtMs => integer()();
  IntColumn get updatedAtMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Browser origins allowed on protected REST routes after adoption or env seed.
class CorsAllowedOrigins extends Table {
  TextColumn get origin => text()();
  IntColumn get createdAtMs => integer()();
  TextColumn get source => text()();

  @override
  Set<Column<Object>> get primaryKey => {origin};
}

/// [CorsAllowedOrigins.source] for successful adoption confirm/grant.
const String kCorsOriginSourceAdoption = 'adoption';

/// [CorsAllowedOrigins.source] for [WADDLE_DISPLAY_HTTP_CORS_ORIGINS] at startup.
const String kCorsOriginSourceEnv = 'env';

/// AES-GCM ciphertext for one integration secret ([SecretStore] storage key).
class IntegrationSecrets extends Table {
  TextColumn get secretKey => text()();
  BlobColumn get ciphertext => blob()();
  IntColumn get updatedAtMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {secretKey};
}

/// Platform-wrapped data-encryption key metadata (row id [kSecretStoreDekMetaId]).
class SecretStoreMeta extends Table {
  TextColumn get id => text()();
  BlobColumn get wrappedDek => blob()();
  IntColumn get algorithmVersion => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// [SecretStoreMeta.id] for the single wrapped DEK row.
const String kSecretStoreDekMetaId = 'dek_v1';

/// Drop-in plugins discovered under the configured plugins directory.
class InstalledPlugins extends Table {
  TextColumn get id => text()();
  TextColumn get version => text()();
  TextColumn get manifestJson => text()();
  TextColumn get installPath => text()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  IntColumn get installedAtMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Mutable runtime booleans/values for curator predicates and overlay triggers.
class RuntimeSignals extends Table {
  TextColumn get id => text()();
  TextColumn get valueJson => text()();
  IntColumn get updatedAtMs => integer()();
  TextColumn get sourcePluginId => text().nullable()();
  IntColumn get ttlSeconds => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
