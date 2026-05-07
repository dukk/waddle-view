import 'dart:async';

import '../curator/ticker_item.dart';
import 'ticker_curated_repository.dart';

/// In-process ticker items; not persisted. [watchOrdered] replays the current
/// list to new subscribers, then follows updates.
class MemoryTickerCuratedRepository implements TickerCuratedRepository {
  List<TickerItem> _items = const [];
  final _updates = StreamController<List<TickerItem>>.broadcast();

  @override
  Future<void> replaceAll(List<TickerItem> items) async {
    _items = List<TickerItem>.unmodifiable(List<TickerItem>.from(items));
    if (!_updates.isClosed) {
      _updates.add(_items);
    }
  }

  @override
  Stream<List<TickerItem>> watchOrdered() async* {
    yield _items;
    yield* _updates.stream;
  }

  @override
  Future<List<TickerItem>> snapshot() async => _items;

  void dispose() {
    _updates.close();
  }
}
