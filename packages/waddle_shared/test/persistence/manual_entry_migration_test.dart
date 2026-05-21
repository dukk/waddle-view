import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:waddle_shared/persistence/database.dart';

void main() {
  test('schema 44 to 45 rewrites manual bucket provenance and removes integrations',
      () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute('''
CREATE TABLE photos (
  id TEXT NOT NULL PRIMARY KEY,
  category TEXT NOT NULL DEFAULT 'pexels',
  data_provider TEXT NOT NULL DEFAULT 'pexels',
  media_blob_key TEXT NOT NULL,
  photographer_name TEXT NOT NULL DEFAULT '',
  photographer_url TEXT NOT NULL DEFAULT '',
  page_url TEXT NOT NULL DEFAULT '',
  alt_text TEXT NOT NULL DEFAULT '',
  fetched_at_ms INTEGER NOT NULL,
  suppressed INTEGER NOT NULL DEFAULT 0
);
''');
      raw.execute('''
CREATE TABLE videos (
  id TEXT NOT NULL PRIMARY KEY,
  category TEXT NOT NULL DEFAULT 'pexels',
  data_provider TEXT NOT NULL DEFAULT 'pexels',
  media_blob_key TEXT NOT NULL,
  photographer_name TEXT NOT NULL DEFAULT '',
  photographer_url TEXT NOT NULL DEFAULT '',
  pexels_page_url TEXT NOT NULL DEFAULT '',
  alt_text TEXT NOT NULL DEFAULT '',
  duration_seconds INTEGER NOT NULL,
  fetched_at_ms INTEGER NOT NULL,
  suppressed INTEGER NOT NULL DEFAULT 0
);
''');
      raw.execute('''
CREATE TABLE calendar_events (
  id TEXT NOT NULL PRIMARY KEY,
  title TEXT NOT NULL,
  start_ms INTEGER NOT NULL,
  end_ms INTEGER NOT NULL,
  all_day INTEGER NOT NULL DEFAULT 0,
  location TEXT,
  description TEXT,
  source TEXT NOT NULL DEFAULT '',
  category_id TEXT,
  external_id TEXT,
  ical_uid TEXT,
  updated_at_ms INTEGER NOT NULL
);
''');
      raw.execute('''
CREATE TABLE trivia_questions (
  id TEXT NOT NULL PRIMARY KEY,
  category_id TEXT NOT NULL,
  question TEXT NOT NULL,
  option_a TEXT NOT NULL,
  option_b TEXT NOT NULL,
  option_c TEXT NOT NULL,
  option_d TEXT NOT NULL,
  correct_option TEXT NOT NULL,
  created_at_ms INTEGER NOT NULL,
  integration_id TEXT,
  suppressed INTEGER NOT NULL DEFAULT 0
);
''');
      raw.execute('''
CREATE TABLE integrations (
  id TEXT NOT NULL PRIMARY KEY,
  integration_type TEXT NOT NULL,
  enabled INTEGER NOT NULL DEFAULT 1,
  poll_seconds INTEGER NOT NULL DEFAULT 60,
  config_json TEXT
);
''');
      raw.execute('''
CREATE TABLE integration_types (
  integration_type TEXT NOT NULL PRIMARY KEY,
  label TEXT NOT NULL,
  config_json_schema TEXT,
  requires_accounts INTEGER NOT NULL DEFAULT 0
);
''');
      raw.execute(
        "INSERT INTO photos (id, data_provider, media_blob_key, fetched_at_ms) "
        "VALUES ('p1', 'photo_bucket', 'k', 1)",
      );
      raw.execute(
        "INSERT INTO videos (id, data_provider, media_blob_key, duration_seconds, fetched_at_ms) "
        "VALUES ('v1', 'video_bucket', 'k', 10, 1)",
      );
      raw.execute(
        "INSERT INTO calendar_events (id, title, start_ms, end_ms, source, updated_at_ms) "
        "VALUES ('c1', 'Lunch', 1, 2, 'calendar_bucket', 1)",
      );
      raw.execute(
        "INSERT INTO trivia_questions (id, category_id, question, option_a, option_b, "
        "option_c, option_d, correct_option, created_at_ms, integration_id) "
        "VALUES ('t1', 'sci', 'Q?', 'a', 'b', 'c', 'd', 'A', 1, 'default_trivia_bucket')",
      );
      raw.execute(
        "INSERT INTO integrations (id, integration_type, enabled, poll_seconds) "
        "VALUES ('default_photo_bucket', 'photo_bucket', 1, 60)",
      );
      raw.execute(
        "INSERT INTO integration_types (integration_type, label, requires_accounts) "
        "VALUES ('photo_bucket', 'Photo Bucket', 0)",
      );
      raw.execute('PRAGMA user_version = 44');
    });
    final db = AppDatabase(
      DatabaseConnection(executor, closeStreamsSynchronously: true),
    );
    await db.customStatement('SELECT 1');

    final photo = await db
        .customSelect("SELECT data_provider FROM photos WHERE id = 'p1'")
        .getSingle();
    expect(photo.read<String>('data_provider'), 'manual_entry');

    final video = await db
        .customSelect("SELECT data_provider FROM videos WHERE id = 'v1'")
        .getSingle();
    expect(video.read<String>('data_provider'), 'manual_entry');

    final event = await db
        .customSelect("SELECT source FROM calendar_events WHERE id = 'c1'")
        .getSingle();
    expect(event.read<String>('source'), 'manual_entry');

    final trivia = await db
        .customSelect(
          "SELECT integration_id FROM trivia_questions WHERE id = 't1'",
        )
        .getSingle();
    expect(trivia.read<String?>('integration_id'), isNull);

    final integrations =
        await db.customSelect('SELECT id FROM integrations').get();
    expect(integrations, isEmpty);

    final types =
        await db.customSelect('SELECT integration_type FROM integration_types')
            .get();
    expect(types, isEmpty);

    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 45);

    await db.close();
  });
}
