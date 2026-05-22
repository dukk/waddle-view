/// Active live-preview capture implementation (for GET /v1/display/live-preview).
enum LivePreviewCaptureBackend {
  widget('widget'),
  gstreamer('gstreamer'),
  ffmpeg('ffmpeg'),
  testPattern('test_pattern');

  const LivePreviewCaptureBackend(this.id);

  final String id;
}

/// Updated when [createPlatformLivePreviewCapture] runs or capture starts.
LivePreviewCaptureBackend livePreviewActiveBackend =
    LivePreviewCaptureBackend.testPattern;
