import 'dart:async';
import 'dart:typed_data';

import 'package:waddle_shared/config/display_live_preview.dart';

import 'live_preview_capture_backend.dart';
import 'live_preview_test_pattern.dart';

class LivePreviewCaptureException implements Exception {
  LivePreviewCaptureException(this.code);

  final String code;

  @override
  String toString() => 'LivePreviewCaptureException($code)';
}

/// Captures the display window and emits JPEG frames.
abstract class LivePreviewCapture {
  Future<void> start(DisplayLivePreviewConfig config);

  /// JPEG frames as extracted from the capture backend.
  Stream<Uint8List> get frames;

  Future<void> stop();

  bool get isRunning;
}

/// Emits a visible test JPEG at [config.fps] (unit tests / harness only).
class TestPatternLivePreviewCapture implements LivePreviewCapture {
  TestPatternLivePreviewCapture();

  final _controller = StreamController<Uint8List>.broadcast();
  Timer? _timer;
  var _running = false;

  @override
  Stream<Uint8List> get frames => _controller.stream;

  @override
  bool get isRunning => _running;

  @override
  Future<void> start(DisplayLivePreviewConfig config) async {
    if (_running) return;
    _running = true;
    livePreviewActiveBackend = LivePreviewCaptureBackend.testPattern;
    final period = Duration(milliseconds: (1000 / config.fps).round().clamp(33, 1000));
    _timer = Timer.periodic(period, (_) {
      if (!_controller.isClosed) {
        _controller.add(kLivePreviewTestPatternJpeg);
      }
    });
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _running = false;
  }
}
