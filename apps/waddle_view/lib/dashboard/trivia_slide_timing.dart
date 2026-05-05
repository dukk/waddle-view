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

const int kTriviaWrongAnswerFadeMs = 320;

/// Time from reveal start until the last wrong option finishes fading out.
int triviaEliminationEndMs(int eliminationWindowMs) {
  final step = eliminationWindowMs ~/ 4;
  if (step < 1) {
    return eliminationWindowMs + kTriviaWrongAnswerFadeMs;
  }
  return 3 * step + kTriviaWrongAnswerFadeMs;
}
