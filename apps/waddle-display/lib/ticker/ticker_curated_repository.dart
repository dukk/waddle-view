import '../curator/ticker_item.dart';

abstract class TickerCuratedRepository {
  Future<void> replaceAll(List<TickerItem> items);

  Stream<List<TickerItem>> watchOrdered();

  /// Latest curated list (for REST and one-shot reads).
  Future<List<TickerItem>> snapshot();
}
