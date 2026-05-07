import 'package:flutter_test/flutter_test.dart';

import 'package:waddle_display/curator/ticker_item.dart';
import 'package:waddle_display/ticker/memory_ticker_curated_repository.dart';

void main() {
  test('replaceAll updates order; watchOrdered emits', () async {
    final repo = MemoryTickerCuratedRepository();
    addTearDown(repo.dispose);
    await repo.replaceAll([
      const TickerItem(kind: 'a', body: 'one', sourceId: 's1'),
      const TickerItem(kind: 'b', body: 'two'),
    ]);
    expect(
      await repo.snapshot(),
      equals([
        const TickerItem(kind: 'a', body: 'one', sourceId: 's1'),
        const TickerItem(kind: 'b', body: 'two'),
      ]),
    );
    await expectLater(
      repo.watchOrdered().take(1),
      emits(
        equals([
          const TickerItem(kind: 'a', body: 'one', sourceId: 's1'),
          const TickerItem(kind: 'b', body: 'two'),
        ]),
      ),
    );
  });

  test('replaceAll replaces prior snapshot', () async {
    final repo = MemoryTickerCuratedRepository();
    addTearDown(repo.dispose);
    await repo.replaceAll([
      const TickerItem(kind: 'x', body: 'a'),
    ]);
    await repo.replaceAll([
      const TickerItem(kind: 'y', body: 'b'),
    ]);
    expect(await repo.snapshot(), [
      const TickerItem(kind: 'y', body: 'b'),
    ]);
  });
}
