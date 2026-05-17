import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:waddle_shared/persistence/database.dart';

void main() {
  test('schema 1 to 2 renames interest catalog tables and preserves rows', () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute('''
CREATE TABLE weather_locations (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  latitude REAL NOT NULL,
  longitude REAL NOT NULL,
  enabled INTEGER NOT NULL DEFAULT 1,
  include_active_weather_alerts INTEGER NOT NULL DEFAULT 1
);
''');
      raw.execute('''
CREATE TABLE rss_feed_sources (
  id TEXT NOT NULL PRIMARY KEY,
  url TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'general',
  poll_seconds INTEGER NOT NULL DEFAULT 3600,
  max_articles INTEGER NOT NULL DEFAULT 3,
  enabled INTEGER NOT NULL DEFAULT 1,
  last_fetched_at INTEGER,
  title TEXT,
  consecutive_failures INTEGER NOT NULL DEFAULT 0,
  next_retry_at INTEGER
);
''');
      raw.execute('''
CREATE TABLE joke_categories (
  id TEXT NOT NULL PRIMARY KEY,
  label TEXT NOT NULL,
  is_seasonal INTEGER NOT NULL DEFAULT 0,
  start_month INTEGER,
  start_day INTEGER,
  end_month INTEGER,
  end_day INTEGER,
  category_prompt TEXT,
  min_jokes INTEGER NOT NULL DEFAULT 10,
  max_jokes INTEGER NOT NULL DEFAULT 100
);
''');
      raw.execute('''
CREATE TABLE trivia_categories (
  id TEXT NOT NULL PRIMARY KEY,
  label TEXT NOT NULL,
  is_seasonal INTEGER NOT NULL DEFAULT 0,
  start_month INTEGER,
  start_day INTEGER,
  end_month INTEGER,
  end_day INTEGER,
  category_prompt TEXT,
  min_questions INTEGER NOT NULL DEFAULT 10,
  max_questions INTEGER NOT NULL DEFAULT 100
);
''');
      raw.execute('''
CREATE TABLE stock_symbols (
  id TEXT NOT NULL PRIMARY KEY,
  symbol TEXT NOT NULL,
  display_name TEXT NOT NULL DEFAULT '',
  enabled INTEGER NOT NULL DEFAULT 1
);
''');
      raw.execute(
        "INSERT INTO weather_locations (id, name, latitude, longitude) "
        "VALUES ('loc1', 'Test City', 40.0, -75.0)",
      );
      raw.execute(
        "INSERT INTO rss_feed_sources (id, url) "
        "VALUES ('feed1', 'https://example.com/rss')",
      );
      raw.execute(
        "INSERT INTO joke_categories (id, label) VALUES ('dad', 'Dad jokes')",
      );
      raw.execute(
        "INSERT INTO trivia_categories (id, label) VALUES ('sci', 'Science')",
      );
      raw.execute(
        "INSERT INTO stock_symbols (id, symbol) VALUES ('sym1', 'AAPL')",
      );
      raw.execute('PRAGMA user_version = 1');
    });
    final connection = DatabaseConnection(
      executor,
      closeStreamsSynchronously: true,
    );

    final db = AppDatabase(connection);
    await db.customStatement('SELECT 1');

    final tables = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name LIKE 'interests_%'",
    ).get();
    final names = tables.map((r) => r.read<String>('name')).toSet();
    expect(
      names,
      {
        'interests_locations',
        'interests_rss_feeds',
        'interests_jokes',
        'interests_trivia',
        'interests_stock_symbols',
        'interests_home_assistant_entities',
      },
    );

    final loc = await db.customSelect(
      'SELECT name FROM interests_locations WHERE id = ?',
      variables: [Variable<String>('loc1')],
    ).getSingle();
    expect(loc.read<String>('name'), 'Test City');

    final feed = await db.customSelect(
      'SELECT url FROM interests_rss_feeds WHERE id = ?',
      variables: [Variable<String>('feed1')],
    ).getSingle();
    expect(feed.read<String>('url'), 'https://example.com/rss');

    final joke = await db.customSelect(
      'SELECT label FROM interests_jokes WHERE id = ?',
      variables: [Variable<String>('dad')],
    ).getSingle();
    expect(joke.read<String>('label'), 'Dad jokes');

    final trivia = await db.customSelect(
      'SELECT label FROM interests_trivia WHERE id = ?',
      variables: [Variable<String>('sci')],
    ).getSingle();
    expect(trivia.read<String>('label'), 'Science');

    final sym = await db.customSelect(
      'SELECT symbol FROM interests_stock_symbols WHERE id = ?',
      variables: [Variable<String>('sym1')],
    ).getSingle();
    expect(sym.read<String>('symbol'), 'AAPL');

    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), db.schemaVersion);

    await db.close();
  });
}
