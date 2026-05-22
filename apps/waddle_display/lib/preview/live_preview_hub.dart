import 'dart:async';
import 'dart:typed_data';

import 'package:waddle_shared/config/display_live_preview.dart';

import 'live_preview_capture.dart';
import 'live_preview_platform.dart';

/// Single shared capture instance; starts when the first viewer connects.
class LivePreviewHub {
  LivePreviewHub({LivePreviewCapture? capture})
      : _capture = capture ?? createPlatformLivePreviewCapture();

  final LivePreviewCapture _capture;
  var _viewers = 0;
  StreamSubscription<Uint8List>? _frameSub;
  final _broadcast = StreamController<Uint8List>.broadcast();

  Stream<Uint8List> get frames => _broadcast.stream;

  bool get isCapturing => _capture.isRunning;

  Future<void> attachViewer(DisplayLivePreviewConfig config) async {
    _viewers++;
    if (_viewers == 1) {
      await _capture.start(config);
      _frameSub = _capture.frames.listen(
        (frame) {
          if (!_broadcast.isClosed) {
            _broadcast.add(frame);
          }
        },
        onError: (Object e, StackTrace st) {
          if (!_broadcast.isClosed) {
            _broadcast.addError(e, st);
          }
        },
      );
    }
  }

  Future<void> detachViewer() async {
    if (_viewers <= 0) return;
    _viewers--;
    if (_viewers == 0) {
      await _frameSub?.cancel();
      _frameSub = null;
      await _capture.stop();
    }
  }

  Future<void> dispose() async {
    _viewers = 0;
    await _frameSub?.cancel();
    _frameSub = null;
    await _capture.stop();
    await _broadcast.close();
  }
}

/// Process-wide hub for live-preview WebSocket streaming.
LivePreviewHub? _globalLivePreviewHub;

LivePreviewHub livePreviewHub({LivePreviewCapture? captureForTest}) {
  return _globalLivePreviewHub ??= LivePreviewHub(capture: captureForTest);
}

void resetLivePreviewHubForTest() {
  _globalLivePreviewHub?.dispose();
  _globalLivePreviewHub = null;
}
