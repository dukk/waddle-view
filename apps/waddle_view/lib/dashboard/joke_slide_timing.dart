/// Delay before showing the punchline, as a fraction of slide [dwellMs].
///
/// Uses integer division; when [dwellMs] is 0 or 1, returns 0 so the caller
/// can reveal the punchline on the next frame or immediately.
int punchlineDelayMs(int dwellMs) => dwellMs ~/ 2;
