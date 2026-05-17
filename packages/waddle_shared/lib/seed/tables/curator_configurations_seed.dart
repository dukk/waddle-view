import 'package:drift/drift.dart';
import 'package:waddle_shared/curation/curator_state_predicates.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';

const int _kAllDaysMask = 0x7F;

Future<void> ensureDefaultCuratorConfigurations(AppDatabase db) async {
  final existing = await (db.select(db.curatorConfigurations)
        ..where((t) => t.id.equals('bootstrap')))
      .getSingleOrNull();
  if (existing != null) {
    return;
  }

  await _insertConfig(
    db,
    id: 'bootstrap',
    name: 'Bootstrap / adoption',
    layer: kCuratorLayerExclusive,
    sortOrder: 0,
    programDurationSeconds: 300,
    historyDepth: 1,
    requireNewsPhoto: false,
    defaultConfig: false,
  );
  await _insertRule(
    db,
    id: 'bootstrap_not_adopted',
    configurationId: 'bootstrap',
    priority: 10000,
    statePredicate: kCuratorPredicateDisplayNotAdopted,
  );
  await _members(
    db,
    'bootstrap',
    screens: ['admin_setup', 'dev_local_api', 'controller_invite'],
    tickers: ['ticker_time'],
  );

  await _insertConfig(
    db,
    id: 'night',
    name: 'Night',
    layer: kCuratorLayerBase,
    sortOrder: 10,
    programDurationSeconds: 120,
    historyDepth: 3,
    requireNewsPhoto: false,
    defaultConfig: false,
  );
  await _insertRule(
    db,
    id: 'night_hours',
    configurationId: 'night',
    priority: 10,
    startTimeMinutes: 22 * 60,
    endTimeMinutes: 6 * 60,
    daysOfWeekMask: _kAllDaysMask,
  );
  await _members(
    db,
    'night',
    screens: ['clock_digital', 'clock_analog', 'sleep_message'],
    tickers: ['ticker_time'],
  );

  await _insertConfig(
    db,
    id: 'morning',
    name: 'Morning',
    layer: kCuratorLayerBase,
    sortOrder: 20,
    programDurationSeconds: 180,
    historyDepth: 5,
    requireNewsPhoto: true,
    defaultConfig: false,
  );
  await _insertRule(
    db,
    id: 'morning_hours',
    configurationId: 'morning',
    priority: 10,
    startTimeMinutes: 6 * 60,
    endTimeMinutes: 10 * 60,
    daysOfWeekMask: _kAllDaysMask,
  );
  await _members(
    db,
    'morning',
    screens: [
      'news',
      'news_right',
      'weather',
      'jokes',
      'trivia',
      'photo',
      'clock_digital',
    ],
    tickers: ['ticker_time', 'ticker_weather', 'ticker_news', 'ticker_quote'],
  );

  await _insertConfig(
    db,
    id: 'work',
    name: 'Work',
    layer: kCuratorLayerBase,
    sortOrder: 30,
    programDurationSeconds: 180,
    historyDepth: 5,
    requireNewsPhoto: true,
    defaultConfig: false,
  );
  await _insertRule(
    db,
    id: 'work_hours',
    configurationId: 'work',
    priority: 10,
    startTimeMinutes: 10 * 60,
    endTimeMinutes: 18 * 60,
    daysOfWeekMask: _kAllDaysMask,
  );
  await _members(
    db,
    'work',
    screens: [
      'news',
      'news_columns',
      'stock_quotes',
      'weather',
      'clock_digital',
      'calendar',
    ],
    tickers: [
      'ticker_time',
      'ticker_weather',
      'ticker_news',
      'ticker_stocks',
    ],
  );

  await _insertConfig(
    db,
    id: 'evening',
    name: 'Evening',
    layer: kCuratorLayerBase,
    sortOrder: 40,
    programDurationSeconds: 180,
    historyDepth: 5,
    requireNewsPhoto: false,
    defaultConfig: true,
  );
  await _insertRule(
    db,
    id: 'evening_hours',
    configurationId: 'evening',
    priority: 10,
    startTimeMinutes: 18 * 60,
    endTimeMinutes: 22 * 60,
    daysOfWeekMask: _kAllDaysMask,
  );
  await _members(
    db,
    'evening',
    screens: [
      'jokes',
      'trivia',
      'photo',
      'photo_collage_nine_square',
      'video',
      'weather',
      'clock_digital',
    ],
    tickers: ['ticker_time', 'ticker_quote', 'ticker_custom'],
  );

  await _insertConfig(
    db,
    id: 'waddle_birthday',
    name: 'Waddle birthday',
    layer: kCuratorLayerEnhancement,
    sortOrder: 100,
    programDurationSeconds: 180,
    historyDepth: 5,
    requireNewsPhoto: false,
    defaultConfig: false,
  );
  await _insertRule(
    db,
    id: 'waddle_birthday_may_13',
    configurationId: 'waddle_birthday',
    priority: 1000,
    startMonth: 5,
    startDay: 13,
    repeatAnnually: true,
  );
  await _members(
    db,
    'waddle_birthday',
    overlays: [
      kDefaultBirthdayOverlayExampleId,
      kDefaultBouncingMessageOverlayId,
    ],
  );

  await _insertConfig(
    db,
    id: 'mothers_day',
    name: "Mother's Day",
    layer: kCuratorLayerEnhancement,
    sortOrder: 110,
    programDurationSeconds: 180,
    historyDepth: 5,
    requireNewsPhoto: false,
    defaultConfig: false,
  );
  await _insertRule(
    db,
    id: 'mothers_day_us',
    configurationId: 'mothers_day',
    priority: 1000,
    startMonth: 5,
    startDay: 1,
    nthWeekOfMonth: 2,
    nthWeekday: DateTime.sunday,
    repeatAnnually: true,
  );
  await _members(
    db,
    'mothers_day',
    overlays: [kDefaultMothersDayOverlayId],
  );
}

Future<void> _insertConfig(
  AppDatabase db, {
  required String id,
  required String name,
  required String layer,
  required int sortOrder,
  required int programDurationSeconds,
  required int historyDepth,
  required bool requireNewsPhoto,
  required bool defaultConfig,
  String? themeIdOverride,
}) async {
  await db.into(db.curatorConfigurations).insert(
        CuratorConfigurationsCompanion.insert(
          id: id,
          name: name,
          layer: layer,
          sortOrder: Value(sortOrder),
          programDurationSeconds: Value(programDurationSeconds),
          historyDepth: Value(historyDepth),
          requireNewsPhotoForScreens: Value(requireNewsPhoto),
          themeIdOverride: Value(themeIdOverride),
          defaultConfig: Value(defaultConfig),
        ),
      );
}

Future<void> _insertRule(
  AppDatabase db, {
  required String id,
  required String configurationId,
  required int priority,
  String? statePredicate,
  int? daysOfWeekMask,
  int? startTimeMinutes,
  int? endTimeMinutes,
  int? startMonth,
  int? startDay,
  int? endMonth,
  int? endDay,
  bool repeatAnnually = true,
  int? yearExact,
  int? nthWeekOfMonth,
  int? nthWeekday,
}) async {
  await db.into(db.curatorScheduleRules).insert(
        CuratorScheduleRulesCompanion.insert(
          id: id,
          configurationId: configurationId,
          priority: Value(priority),
          statePredicate: Value(statePredicate),
          daysOfWeekMask: Value(daysOfWeekMask),
          startTimeMinutes: Value(startTimeMinutes),
          endTimeMinutes: Value(endTimeMinutes),
          startMonth: Value(startMonth),
          startDay: Value(startDay),
          endMonth: Value(endMonth),
          endDay: Value(endDay),
          repeatAnnually: Value(repeatAnnually),
          yearExact: Value(yearExact),
          nthWeekOfMonth: Value(nthWeekOfMonth),
          nthWeekday: Value(nthWeekday),
        ),
      );
}

Future<void> _members(
  AppDatabase db,
  String configurationId, {
  List<String> screens = const [],
  List<String> tickers = const [],
  List<String> overlays = const [],
}) async {
  for (final id in screens) {
    await db.into(db.curatorConfigurationMembers).insert(
          CuratorConfigurationMembersCompanion.insert(
            configurationId: configurationId,
            entityType: kCuratorMemberEntityScreen,
            entityId: id,
          ),
        );
  }
  for (final id in tickers) {
    await db.into(db.curatorConfigurationMembers).insert(
          CuratorConfigurationMembersCompanion.insert(
            configurationId: configurationId,
            entityType: kCuratorMemberEntityTicker,
            entityId: id,
          ),
        );
  }
  for (final id in overlays) {
    await db.into(db.curatorConfigurationMembers).insert(
          CuratorConfigurationMembersCompanion.insert(
            configurationId: configurationId,
            entityType: kCuratorMemberEntityOverlay,
            entityId: id,
          ),
        );
  }
}
