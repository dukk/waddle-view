import 'package:waddle_shared/persistence/database.dart';
import '../joke_openai/joke_seasonal_eligibility.dart';

/// Whether a trivia category may be used for generation on [now] (local time).
bool isTriviaCategoryEligibleOn(InterestsTriviaData row, DateTime now) {
  if (!row.isSeasonal) {
    return true;
  }
  final sm = row.startMonth;
  final sd = row.startDay;
  final em = row.endMonth;
  final ed = row.endDay;
  if (sm == null || sd == null || em == null || ed == null) {
    return false;
  }
  final localDay = DateTime(now.year, now.month, now.day);
  return isDateInAnnualSeasonWindow(
    localDay,
    startMonth: sm,
    startDay: sd,
    endMonth: em,
    endDay: ed,
  );
}
