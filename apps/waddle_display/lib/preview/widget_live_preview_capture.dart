import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:image/image.dart' as img;
import 'package:waddle_shared/config/display_live_preview.dart';

import 'live_preview_capture.dart';
import 'live_preview_capture_backend.dart';

/// Captures a [RepaintBoundary] subtree as JPEG frames (Windows/macOS dev).
class WidgetLivePreviewCapture implements LivePreviewCapture {
  WidgetLivePreviewCapture({required this.boundaryKey});

  final GlobalKey boundaryKey;
  final _controller = StreamController<Uint8List>.broadcast();
  Timer? _timer;
  var _running = false;
  DisplayLivePreviewConfig? _config;

  @override
  Stream<Uint8List> get frames => _controller.stream;

  @override
  bool get isRunning => _running;

  @override
  Future<void> start(DisplayLivePreviewConfig config) async {
    if (_running) return;
    _config = config;
    _running = true;
    livePreviewActiveBackend = LivePreviewCaptureBackend.widget;
    final period = Duration(
      milliseconds: (1000 / config.fps).round().clamp(33, 1000),
    );
    _timer = Timer.periodic(period, (_) {
      unawaited(_captureFrame());
    });
    unawaited(_captureFrame());
  }

  Future<void> _captureFrame() async {
    if (!_running || _controller.isClosed) return;
    final config = _config;
    if (config == null) return;

    final boundary = boundaryKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) return;

    try {
      final logicalW = boundary.size.width;
      if (logicalW <= 0) return;
      final pixelRatio = (config.width / logicalW).clamp(0.25, 3.0);
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      try {
        final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (byteData == null) return;
        final rgba = img.Image.fromBytes(
          width: image.width,
          height: image.height,
          bytes: byteData.buffer,
          bytesOffset: byteData.offsetInBytes,
          numChannels: 4,
        );
        final jpeg = Uint8List.fromList(
          img.encodeJpg(rgba, quality: config.quality),
        );
        if (!_controller.isClosed && jpeg.isNotEmpty) {
          _controller.add(jpeg);
        }
      } finally {
        image.dispose();
      }
    } catch (_) {
      // Skip frame when layout not ready or GPU busy.
    }
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _running = false;
    _config = null;
  }
}
