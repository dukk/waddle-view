import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:waddle_shared/config/display_live_preview.dart';

import 'live_preview_capture.dart';
import 'live_preview_capture_backend.dart';
import 'linux_gstreamer_live_preview_capture.dart';
import 'linux_window_xid.dart';

/// Linux window capture: GStreamer first, ffmpeg x11grab fallback.
class LinuxDesktopLivePreviewCapture implements LivePreviewCapture {
  LinuxDesktopLivePreviewCapture({
    Future<int?> Function()? resolveWindowXid,
  }) : _resolveWindowXid = resolveWindowXid ?? resolveLinuxCaptureWindowXidWithRetry;

  final Future<int?> Function() _resolveWindowXid;
  final _broadcast = StreamController<Uint8List>.broadcast();
  LivePreviewCapture? _inner;
  StreamSubscription<Uint8List>? _innerSub;
  var _running = false;

  @override
  Stream<Uint8List> get frames => _broadcast.stream;

  @override
  bool get isRunning => _running;

  @override
  Future<void> start(DisplayLivePreviewConfig config) async {
    if (_running) return;
    if (kIsWeb || !Platform.isLinux) {
      throw LivePreviewCaptureException('live_preview_linux_only');
    }

    final xid = await _resolveWindowXid();
    if (xid == null) {
      throw LivePreviewCaptureException('live_preview_window_not_found');
    }

    _running = true;
    final gstreamer = LinuxGstreamerLivePreviewCapture(
      windowXid: xid,
      resolveWindowXid: _resolveWindowXid,
    );
    try {
      await _startInner(gstreamer, config);
      livePreviewActiveBackend = LivePreviewCaptureBackend.gstreamer;
    } catch (_) {
      await gstreamer.stop();
      final ffmpeg = LinuxFfmpegLivePreviewCapture(windowXid: xid);
      await _startInner(ffmpeg, config);
      livePreviewActiveBackend = LivePreviewCaptureBackend.ffmpeg;
    }
  }

  Future<void> _startInner(
    LivePreviewCapture inner,
    DisplayLivePreviewConfig config,
  ) async {
    await _innerSub?.cancel();
    _inner = inner;
    await inner.start(config);
    _innerSub = inner.frames.listen(
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

  @override
  Future<void> stop() async {
    _running = false;
    await _innerSub?.cancel();
    _innerSub = null;
    await _inner?.stop();
    _inner = null;
  }
}

/// Retries window lookup while the Flutter window is starting.
Future<int?> resolveLinuxCaptureWindowXidWithRetry({
  Duration timeout = const Duration(seconds: 5),
  Duration interval = const Duration(milliseconds: 250),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final xid = await resolveLinuxCaptureWindowXid();
    if (xid != null) return xid;
    await Future<void>.delayed(interval);
  }
  return null;
}
