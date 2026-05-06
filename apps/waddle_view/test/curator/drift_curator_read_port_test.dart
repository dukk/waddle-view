import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_view/curator/drift_curator_read_port.dart';
import 'package:waddle_view/persistence/database.dart';

import '../helpers/memory_database.dart';

void main() {
  test('loadNewsCandidatesForTicker uses feed title for feedName', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.rssFeedSources).insert(
          RssFeedSourcesCompanion.insert(
            id: 'f1',
            url: 'http://x',
            title: const Value('US Top Stories'),
            category: const Value('usa'),
          ),
        );
    await db.into(db.rssArticles).insert(
          RssArticlesCompanion.insert(
            id: 'a1',
            feedId: 'f1',
            guid: 'g1',
            title: 'Headline',
            link: 'http://l',
            publishedAt: DateTime.fromMillisecondsSinceEpoch(1),
            fetchedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    final port = DriftCuratorReadPort(db);
    final list = await port.loadNewsCandidatesForTicker();
    expect(list.single.feedName, 'US Top Stories');
    await db.close();
  });

  test('loadNewsCandidatesForTicker falls back to category when title empty', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.rssFeedSources).insert(
          RssFeedSourcesCompanion.insert(
            id: 'f1',
            url: 'http://x',
            category: const Value('world'),
          ),
        );
    await db.into(db.rssArticles).insert(
          RssArticlesCompanion.insert(
            id: 'a1',
            feedId: 'f1',
            guid: 'g1',
            title: 'Headline',
            link: 'http://l',
            publishedAt: DateTime.fromMillisecondsSinceEpoch(1),
            fetchedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        );
    final port = DriftCuratorReadPort(db);
    final list = await port.loadNewsCandidatesForTicker();
    expect(list.single.feedName, 'world');
    await db.close();
  });
}
