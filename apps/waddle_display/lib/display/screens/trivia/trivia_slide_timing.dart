/// Optional override from layout JSON `eliminationWindowMs`; otherwise derived
/// from slide [dwellMs].
int triviaEliminationWindowMs(int dwellMs, {int? configOverride}) {
  if (configOverride != null && configOverride > 0) {
    return configOverride;
  }
  final scaled = (dwellMs * 0.75).round();
  final reserve = dwellMs - 1500;
  final w = scaled > reserve ? scaled : reserve;
  return w < 1 ? dwellMs : w;
}

const int kTriviaStrikeAnimationMs = 320;

/// Time from reveal start until the last wrong option finishes its strike-out
/// animation.
int triviaEliminationEndMs(
  int eliminationWindowMs, {
  int strikeAnimationMs = kTriviaStrikeAnimationMs,
}) {
  final step = eliminationWindowMs ~/ 4;
  if (step < 1) {
    return eliminationWindowMs + strikeAnimationMs;
  }
  return 3 * step + strikeAnimationMs;
}
