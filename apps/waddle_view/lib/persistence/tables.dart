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

class TickerScreens extends Table {
  TextColumn get id => text()();
  IntColumn get sortKey => integer().withDefault(const Constant(0))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  IntColumn get dwellMs => integer().withDefault(const Constant(5000))();
  IntColumn get minGapBeforeRepeatMs =>
      integer().withDefault(const Constant(0))();
  TextColumn get contentKind => text().nullable()();
  TextColumn get bodyText => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class TickerConditionGroups extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get screenId => text().references(TickerScreens, #id)();
  TextColumn get matchMode => text().withDefault(const Constant('ALL'))();
}

class TickerConditions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get groupId => integer().references(TickerConditionGroups, #id)();
  TextColumn get kind => text()();
  TextColumn get paramsJson => text().withDefault(const Constant('{}'))();
}

class TickerScreenRuntimes extends Table {
  TextColumn get screenId => text().references(TickerScreens, #id)();
  IntColumn get lastStartedAt => integer().nullable()();
  IntColumn get lastEndedAt => integer().nullable()();
  IntColumn get showsOnLocalDay => integer().withDefault(const Constant(0))();
  TextColumn get localDayKey => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {screenId};
}
