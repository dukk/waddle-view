import 'package:drift/drift.dart';
import 'package:waddle_shared/curation/curator_state_predicates.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'package:waddle_shared/persistence/tables.dart';

const int _kAllDaysMask = 0x7F;
const int _kWeekdayDaysMask = 0x1F;
const int _kWeekendDaysMask = 0x60;

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
  await _insertConfig(
    db,
    id: kDefaultBaseCuratorConfigurationId,
    name: 'Default',
    layer: kCuratorLayerBase,
    sortOrder: 5,
    programDurationSeconds: 180,
    historyDepth: 5,
    requireNewsPhoto: true,
    defaultConfig: false,
  );
  await _insertConfig(
    db,
    id: 'weekday',
    name: 'Weekdays',
    layer: kCuratorLayerEnhancement,
    sortOrder: 10,
    programDurationSeconds: 180,
    historyDepth: 5,
    requireNewsPhoto: true,
    defaultConfig: false,
  );
  await _insertRule(
    db,
    id: 'weekday_days',
    configurationId: 'weekday',
    priority: 10,
    daysOfWeekMask: _kWeekdayDaysMask,
  );
  await _insertConfig(
    db,
    id: 'weekend',
    name: 'Weekend',
    layer: kCuratorLayerEnhancement,
    sortOrder: 10,
    programDurationSeconds: 180,
    historyDepth: 5,
    requireNewsPhoto: true,
    defaultConfig: false,
  );
  await _insertRule(
    db,
    id: 'weekend_days',
    configurationId: 'weekend',
    priority: 10,
    daysOfWeekMask: _kWeekendDaysMask,
  );
  await _insertConfig(
    db,
    id: 'night',
    name: 'Night',
    layer: kCuratorLayerBase,
    sortOrder: 100,
    programDurationSeconds: 120,
    historyDepth: 3,
    requireNewsPhoto: false,
    defaultConfig: false,
    parentConfigurationId: kDefaultBaseCuratorConfigurationId,
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
  await _insertConfig(
    db,
    id: 'morning',
    name: 'Morning',
    layer: kCuratorLayerBase,
    sortOrder: 110,
    programDurationSeconds: 180,
    historyDepth: 5,
    requireNewsPhoto: true,
    defaultConfig: false,
    parentConfigurationId: kDefaultBaseCuratorConfigurationId,
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
  await _insertConfig(
    db,
    id: 'work',
    name: 'Work',
    layer: kCuratorLayerBase,
    sortOrder: 120,
    programDurationSeconds: 180,
    historyDepth: 5,
    requireNewsPhoto: true,
    defaultConfig: false,
    parentConfigurationId: kDefaultBaseCuratorConfigurationId,
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
  await _insertConfig(
    db,
    id: 'evening',
    name: 'Evening',
    layer: kCuratorLayerBase,
    sortOrder: 130,
    programDurationSeconds: 180,
    historyDepth: 5,
    requireNewsPhoto: false,
    defaultConfig: true,
    parentConfigurationId: kDefaultBaseCuratorConfigurationId,
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
  await _insertConfig(
    db,
    id: 'waddle_birthday',
    name: 'Waddle birthday',
    layer: kCuratorLayerEnhancement,
    sortOrder: 200,
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
  await _insertConfig(
    db,
    id: 'mothers_day',
    name: "Mother's Day",
    layer: kCuratorLayerEnhancement,
    sortOrder: 210,
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
  await reseedDefaultCuratorCatalogMembers(db);
}

/// Re-applies factory screen/ticker/overlay membership ops for built-in curator configs.
Future<void> reseedDefaultCuratorCatalogMembers(AppDatabase db) async {
  await _members(
    db,
    'bootstrap',
    screensAdd: ['admin_setup', 'dev_local_api', 'controller_invite'],
    tickersAdd: ['ticker_time'],
  );
  await _members(
    db,
    kDefaultBaseCuratorConfigurationId,
    screensAdd: kDefaultBaseCuratorScreenMemberIds,
    tickersAdd: kDefaultBaseCuratorTickerMemberIds,
  );
  await _members(
    db,
    'weekday',
    screensRemove: [
      'photo',
      'photo_collage_nine_square',
      'video',
    ],
  );
  await _members(
    db,
    'weekend',
    screensAdd: [
      'photo',
      'photo_collage_nine_square',
      'video',
      'jokes',
      'trivia',
    ],
    screensRemove: ['stock_quotes', 'news_columns', 'calendar'],
    tickersAdd: ['ticker_custom'],
    tickersRemove: ['ticker_stocks'],
  );
  await _members(
    db,
    'night',
    screensAdd: ['clock_analog', 'sleep_message'],
  );
  await _members(
    db,
    'morning',
    screensAdd: [
      'news',
      'news_right',
      'weather',
      'jokes',
      'trivia',
      'photo',
    ],
    tickersAdd: ['ticker_weather', 'ticker_news'],
  );
  await _members(
    db,
    'work',
    screensAdd: [
      'news',
      'news_columns',
      'stock_quotes',
      'weather',
      'calendar',
    ],
    tickersAdd: [
      'ticker_weather',
      'ticker_news',
      'ticker_stocks',
    ],
  );
  await _members(
    db,
    'evening',
    screensAdd: [
      'jokes',
      'trivia',
      'photo',
      'photo_collage_nine_square',
      'video',
      'weather',
    ],
    tickersAdd: ['ticker_custom'],
  );
  await _members(
    db,
    'waddle_birthday',
    overlaysAdd: [
      kDefaultBirthdayConfettiOverlayId,
      kDefaultWattleViewsBirthdayMessageOverlayId,
    ],
  );
  await _members(
    db,
    'mothers_day',
    overlaysAdd: [kDefaultMothersDayOverlayId],
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
  String? parentConfigurationId,
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
          parentConfigurationId: Value(parentConfigurationId),
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
  List<String> screensAdd = const [],
  List<String> screensRemove = const [],
  List<String> tickersAdd = const [],
  List<String> tickersRemove = const [],
  List<String> overlaysAdd = const [],
  List<String> overlaysRemove = const [],
}) async {
  await _insertMemberOps(
    db,
    configurationId,
    kCuratorMemberEntityScreen,
    screensAdd,
    kCuratorMemberOpAdd,
  );
  await _insertMemberOps(
    db,
    configurationId,
    kCuratorMemberEntityScreen,
    screensRemove,
    kCuratorMemberOpRemove,
  );
  await _insertMemberOps(
    db,
    configurationId,
    kCuratorMemberEntityTicker,
    tickersAdd,
    kCuratorMemberOpAdd,
  );
  await _insertMemberOps(
    db,
    configurationId,
    kCuratorMemberEntityTicker,
    tickersRemove,
    kCuratorMemberOpRemove,
  );
  await _insertMemberOps(
    db,
    configurationId,
    kCuratorMemberEntityOverlay,
    overlaysAdd,
    kCuratorMemberOpAdd,
  );
  await _insertMemberOps(
    db,
    configurationId,
    kCuratorMemberEntityOverlay,
    overlaysRemove,
    kCuratorMemberOpRemove,
  );
}

Future<void> _insertMemberOps(
  AppDatabase db,
  String configurationId,
  String entityType,
  List<String> entityIds,
  String op,
) async {
  for (final id in entityIds) {
    await db.into(db.curatorConfigurationMembers).insert(
          CuratorConfigurationMembersCompanion.insert(
            configurationId: configurationId,
            entityType: entityType,
            entityId: id,
            op: Value(op),
          ),
        );
  }
}
