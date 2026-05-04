import 'ticker_models.dart';

abstract class TickerScheduleRepository {
  Future<List<TickerScreenBundle>> loadBundles();

  Future<void> onShowStart(String screenId, DateTime nowLocal);

  Future<void> onShowEnd(String screenId, DateTime nowLocal);
}
