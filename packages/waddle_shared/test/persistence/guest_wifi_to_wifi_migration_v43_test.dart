import 'dart:convert';

import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:waddle_shared/persistence/database.dart';

void main() {
  test('v42 -> v43 migrates guest_wifi screens and copies KV into config_json', () async {
    final raw = sqlite.sqlite3.openInMemory();
    raw.execute('PRAGMA foreign_keys = ON;');
    raw.execute('''
CREATE TABLE screen_definitions (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  enabled INTEGER NOT NULL DEFAULT 1,
  screen_type TEXT NOT NULL,
  config_json TEXT NOT NULL DEFAULT '{}',
  config_json_schema TEXT,
  example_config_json TEXT,
  dwell_seconds INTEGER NOT NULL DEFAULT 10,
  frequency_weight INTEGER NOT NULL DEFAULT 100,
  min_gap_between_shows_seconds INTEGER NOT NULL DEFAULT 0,
  min_placements_per_program INTEGER NOT NULL DEFAULT 0,
  max_placements_per_program INTEGER,
  data_key TEXT NOT NULL DEFAULT ''
);
''');
    raw.execute('''
CREATE TABLE config_key_values (
  key TEXT NOT NULL PRIMARY KEY,
  value TEXT NOT NULL
);
''');
    raw.execute(
      "INSERT INTO config_key_values VALUES "
      "('dashboard.guest_wifi.connection', 'WIFI:T:WPA;S:Lobby;P:guestpass;;');",
    );
    raw.execute(
      "INSERT INTO screen_definitions (id, name, screen_type, config_json, data_key) "
      "VALUES ('guest_wifi', 'Guest WiFi', 'guest_wifi', "
      "'{\"kvKey\":\"wifi.staff\",\"headline\":\"Staff\"}', 'guest_wifi');",
    );
    raw.execute(
      "INSERT INTO config_key_values VALUES "
      "('wifi.staff', 'WIFI:T:WPA;S:StaffNet;P:staffsecret;;');",
    );
    raw.execute('PRAGMA user_version = 42;');

    final db = AppDatabase(NativeDatabase.opened(raw));
    await db.customSelect('SELECT 1').get();

    final row = await (db.select(db.screens)
          ..where((t) => t.id.equals('guest_wifi')))
        .getSingle();
    expect(row.screenType, 'wifi');
    final cfg = jsonDecode(row.configJson) as Map<String, dynamic>;
    expect(cfg['headline'], 'Staff');
    expect(cfg['connection'], 'WIFI:T:WPA;S:StaffNet;P:staffsecret;;');
    expect(cfg.containsKey('kvKey'), isFalse);

    final ver = await db.customSelect('PRAGMA user_version').getSingle();
    expect(ver.read<int>('user_version'), 48);

    await db.close();
  });

  test('v42 -> v43 prefers existing connection in config over KV', () async {
    final raw = sqlite.sqlite3.openInMemory();
    raw.execute('PRAGMA foreign_keys = ON;');
    raw.execute('''
CREATE TABLE screen_definitions (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  enabled INTEGER NOT NULL DEFAULT 1,
  screen_type TEXT NOT NULL,
  config_json TEXT NOT NULL DEFAULT '{}',
  config_json_schema TEXT,
  example_config_json TEXT,
  dwell_seconds INTEGER NOT NULL DEFAULT 10,
  frequency_weight INTEGER NOT NULL DEFAULT 100,
  min_gap_between_shows_seconds INTEGER NOT NULL DEFAULT 0,
  min_placements_per_program INTEGER NOT NULL DEFAULT 0,
  max_placements_per_program INTEGER,
  data_key TEXT NOT NULL DEFAULT ''
);
''');
    raw.execute('''
CREATE TABLE config_key_values (
  key TEXT NOT NULL PRIMARY KEY,
  value TEXT NOT NULL
);
''');
    raw.execute(
      "INSERT INTO config_key_values VALUES "
      "('dashboard.guest_wifi.connection', 'WIFI:T:WPA;S:FromKv;P:x;;');",
    );
    raw.execute(
      "INSERT INTO screen_definitions (id, name, screen_type, config_json, data_key) "
      "VALUES ('gw2', 'WiFi', 'guest_wifi', "
      "'{\"connection\":\"WIFI:T:WPA;S:FromCfg;P:y;;\"}', 'gw2');",
    );
    raw.execute('PRAGMA user_version = 42;');

    final db = AppDatabase(NativeDatabase.opened(raw));
    await db.customSelect('SELECT 1').get();

    final row = await (db.select(db.screens)
          ..where((t) => t.id.equals('gw2')))
        .getSingle();
    final cfg = jsonDecode(row.configJson) as Map<String, dynamic>;
    expect(cfg['connection'], 'WIFI:T:WPA;S:FromCfg;P:y;;');

    await db.close();
  });

  test('v42 -> v43 copies default dashboard.guest_wifi.connection when config empty', () async {
    final raw = sqlite.sqlite3.openInMemory();
    raw.execute('PRAGMA foreign_keys = ON;');
    raw.execute('''
CREATE TABLE screen_definitions (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  enabled INTEGER NOT NULL DEFAULT 1,
  screen_type TEXT NOT NULL,
  config_json TEXT NOT NULL DEFAULT '{}',
  config_json_schema TEXT,
  example_config_json TEXT,
  dwell_seconds INTEGER NOT NULL DEFAULT 10,
  frequency_weight INTEGER NOT NULL DEFAULT 100,
  min_gap_between_shows_seconds INTEGER NOT NULL DEFAULT 0,
  min_placements_per_program INTEGER NOT NULL DEFAULT 0,
  max_placements_per_program INTEGER,
  data_key TEXT NOT NULL DEFAULT ''
);
''');
    raw.execute('''
CREATE TABLE config_key_values (
  key TEXT NOT NULL PRIMARY KEY,
  value TEXT NOT NULL
);
''');
    raw.execute(
      "INSERT INTO config_key_values VALUES "
      "('dashboard.guest_wifi.connection', 'WIFI:T:WPA;S:Lobby;P:guestpass;;');",
    );
    raw.execute(
      "INSERT INTO screen_definitions (id, name, screen_type, config_json, data_key) "
      "VALUES ('guest_wifi', 'Guest WiFi', 'guest_wifi', '{}', 'guest_wifi');",
    );
    raw.execute('PRAGMA user_version = 42;');

    final db = AppDatabase(NativeDatabase.opened(raw));
    await db.customSelect('SELECT 1').get();

    final row = await (db.select(db.screens)
          ..where((t) => t.id.equals('guest_wifi')))
        .getSingle();
    expect(row.screenType, 'wifi');
    final cfg = jsonDecode(row.configJson) as Map<String, dynamic>;
    expect(cfg['connection'], 'WIFI:T:WPA;S:Lobby;P:guestpass;;');

    await db.close();
  });
}
