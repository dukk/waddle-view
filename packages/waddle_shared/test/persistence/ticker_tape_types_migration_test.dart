import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:waddle_shared/persistence/database.dart';

void main() {
  test('schema 26 to 27 extracts ticker_tape_types and trims ticker_tapes', () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute('''
CREATE TABLE ticker_tapes (
  id TEXT NOT NULL PRIMARY KEY,
  label TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  ticker_type TEXT NOT NULL,
  frequency_weight INTEGER NOT NULL DEFAULT 100,
  sort_order INTEGER NOT NULL DEFAULT 0,
  config_key TEXT,
  config_json TEXT NOT NULL DEFAULT '{}',
  config_json_schema TEXT,
  example_config_json TEXT
);
''');
      raw.execute(
        "INSERT INTO ticker_tapes "
        "(id, label, ticker_type, config_json, config_json_schema, example_config_json) "
        "VALUES ('ticker_weather', 'Weather', 'weather', '{}', "
        "'{\"type\":\"object\"}', '{}')",
      );
      raw.execute('PRAGMA user_version = 26');
    });
    final db = AppDatabase(
      DatabaseConnection(executor, closeStreamsSynchronously: true),
    );
    await db.customStatement('SELECT 1');

    final typeRows = await db.customSelect(
      'SELECT ticker_type, label FROM ticker_tape_types WHERE ticker_type = ?',
      variables: [const Variable<String>('weather')],
    ).getSingle();
    expect(typeRows.read<String>('label'), 'Weather');

    final columns = await db.customSelect('PRAGMA table_info(ticker_tapes)').get();
    final names = columns.map((c) => c.read<String>('name')).toSet();
    expect(names.contains('config_json_schema'), isFalse);
    expect(names.contains('example_config_json'), isFalse);

    final tape = await db.customSelect(
      'SELECT id, ticker_type FROM ticker_tapes WHERE id = ?',
      variables: [const Variable<String>('ticker_weather')],
    ).getSingle();
    expect(tape.read<String>('ticker_type'), 'weather');

    await db.close();
  });

  test('schema 27 to 28 renames ticker_types to ticker_tape_types', () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute('''
CREATE TABLE ticker_types (
  ticker_type TEXT NOT NULL PRIMARY KEY,
  label TEXT NOT NULL,
  config_json_schema TEXT
);
''');
      raw.execute(
        "INSERT INTO ticker_types (ticker_type, label) VALUES ('news', 'News')",
      );
      raw.execute('PRAGMA user_version = 27');
    });
    final db = AppDatabase(
      DatabaseConnection(executor, closeStreamsSynchronously: true),
    );
    await db.customStatement('SELECT 1');

    final row = await db.customSelect(
      'SELECT label FROM ticker_tape_types WHERE ticker_type = ?',
      variables: [const Variable<String>('news')],
    ).getSingle();
    expect(row.read<String>('label'), 'News');

    final legacyExists = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='ticker_types'",
    ).get();
    expect(legacyExists, isEmpty);

    await db.close();
  });

  test('schema 28 to 29 migrates quote/custom to static_text and strips fallbacks', () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute('''
CREATE TABLE ticker_tape_types (
  ticker_type TEXT NOT NULL PRIMARY KEY,
  label TEXT NOT NULL,
  config_json_schema TEXT
);
''');
      raw.execute('''
CREATE TABLE ticker_tapes (
  id TEXT NOT NULL PRIMARY KEY,
  label TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  ticker_type TEXT NOT NULL,
  frequency_weight INTEGER NOT NULL DEFAULT 100,
  sort_order INTEGER NOT NULL DEFAULT 0,
  config_key TEXT,
  config_json TEXT NOT NULL DEFAULT '{}'
);
''');
      raw.execute('''
CREATE TABLE config_key_values (
  key TEXT NOT NULL PRIMARY KEY,
  value TEXT NOT NULL
);
''');
      raw.execute(
        "INSERT INTO ticker_tapes "
        "(id, label, ticker_type, config_json) VALUES "
        "('ticker_quote', 'Quote', 'quote', '{\"fallbackText\":\"Hello\"}')",
      );
      raw.execute(
        "INSERT INTO ticker_tapes "
        "(id, label, ticker_type, config_key, config_json) VALUES "
        "('ticker_custom', 'Custom', 'custom', 'ticker.marquee.welcome', '{}')",
      );
      raw.execute(
        "INSERT INTO ticker_tapes "
        "(id, label, ticker_type, config_json) VALUES "
        "('ticker_weather', 'Weather', 'weather', "
        "'{\"fallbackText\":\"Cold\"}')",
      );
      raw.execute(
        "INSERT INTO config_key_values (key, value) VALUES "
        "('ticker.marquee.welcome', 'Thanks for visiting')",
      );
      raw.execute('PRAGMA user_version = 28');
    });
    final db = AppDatabase(
      DatabaseConnection(executor, closeStreamsSynchronously: true),
    );
    await db.customStatement('SELECT 1');

    final quote = await db.customSelect(
      'SELECT ticker_type, config_json FROM ticker_tapes WHERE id = ?',
      variables: [const Variable<String>('ticker_quote')],
    ).getSingle();
    expect(quote.read<String>('ticker_type'), 'static_text');
    expect(
      jsonDecode(quote.read<String>('config_json')) as Map,
      {'text': 'Hello'},
    );

    final custom = await db.customSelect(
      'SELECT ticker_type, config_json FROM ticker_tapes WHERE id = ?',
      variables: [const Variable<String>('ticker_custom')],
    ).getSingle();
    expect(custom.read<String>('ticker_type'), 'static_text');
    expect(
      jsonDecode(custom.read<String>('config_json')) as Map,
      {'text': 'Thanks for visiting'},
    );

    final weather = await db.customSelect(
      'SELECT config_json FROM ticker_tapes WHERE id = ?',
      variables: [const Variable<String>('ticker_weather')],
    ).getSingle();
    expect(jsonDecode(weather.read<String>('config_json')) as Map, isEmpty);

    final customLegacy = await db.customSelect(
      "SELECT ticker_type FROM ticker_tape_types WHERE ticker_type = 'custom'",
    ).get();
    expect(customLegacy, isEmpty);

    final quoteType = await db.customSelect(
      "SELECT label FROM ticker_tape_types WHERE ticker_type = 'quote'",
    ).getSingle();
    expect(quoteType.read<String>('label'), 'Quote');

    final staticType = await db.customSelect(
      "SELECT label FROM ticker_tape_types WHERE ticker_type = 'static_text'",
    ).getSingle();
    expect(staticType.read<String>('label'), 'Static text');

    await db.close();
  });

  test('schema 29 to 30 drops config_key from ticker_tapes', () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute('''
CREATE TABLE ticker_tapes (
  id TEXT NOT NULL PRIMARY KEY,
  label TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  ticker_type TEXT NOT NULL,
  frequency_weight INTEGER NOT NULL DEFAULT 100,
  sort_order INTEGER NOT NULL DEFAULT 0,
  config_key TEXT,
  config_json TEXT NOT NULL DEFAULT '{}'
);
''');
      raw.execute(
        "INSERT INTO ticker_tapes "
        "(id, label, ticker_type, config_key, config_json) VALUES "
        "('pinned', 'Pinned', 'static_text', 'ticker.marquee.welcome', '{}')",
      );
      raw.execute('''
CREATE TABLE config_key_values (
  key TEXT NOT NULL PRIMARY KEY,
  value TEXT NOT NULL
);
''');
      raw.execute(
        "INSERT INTO config_key_values (key, value) VALUES "
        "('ticker.marquee.welcome', 'Hello marquee')",
      );
      raw.execute('PRAGMA user_version = 29');
    });
    final db = AppDatabase(
      DatabaseConnection(executor, closeStreamsSynchronously: true),
    );
    await db.customStatement('SELECT 1');

    final columns = await db.customSelect('PRAGMA table_info(ticker_tapes)').get();
    final names = columns.map((c) => c.read<String>('name')).toSet();
    expect(names.contains('config_key'), isFalse);

    final row = await db.customSelect(
      'SELECT config_json FROM ticker_tapes WHERE id = ?',
      variables: [const Variable<String>('pinned')],
    ).getSingle();
    expect(
      jsonDecode(row.read<String>('config_json')) as Map,
      {'text': 'Hello marquee'},
    );

    await db.close();
  });
}
