// Layout and retry helpers for PexelsVideoSlideWidget media_kit playback.

/// Minimum layout extent before attaching a media_kit [Video] texture surface.
const double kPexelsVideoMinLayoutExtent = 32;

/// Maximum automatic playback restarts after a [Player.stream.error] event.
const int kPexelsVideoMaxPlaybackRetries = 3;

/// Whether [width] and [height] from a [LayoutBuilder] are safe for video output.
bool pexelsVideoLayoutSizeReady(double width, double height) {
  if (!width.isFinite || !height.isFinite) {
    return false;
  }
  return width >= kPexelsVideoMinLayoutExtent &&
      height >= kPexelsVideoMinLayoutExtent;
}

/// Backoff before retry attempt [attempt] (1-based).
Duration pexelsVideoRetryDelay(int attempt) {
  final clamped = attempt.clamp(1, kPexelsVideoMaxPlaybackRetries);
  return Duration(milliseconds: 400 * clamped);
}
