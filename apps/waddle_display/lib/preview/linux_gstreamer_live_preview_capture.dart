import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:waddle_shared/config/display_live_preview.dart';

import 'live_preview_capture.dart';

/// Linux X11 window capture via `gst-launch-1.0` + `ximagesrc`.
class LinuxGstreamerLivePreviewCapture implements LivePreviewCapture {
  LinuxGstreamerLivePreviewCapture({
    this.windowXid,
    Future<int?> Function()? resolveWindowXid,
  }) : _resolveWindowXid = resolveWindowXid;

  final int? windowXid;
  final Future<int?> Function()? _resolveWindowXid;
  final _controller = StreamController<Uint8List>.broadcast();
  Process? _process;
  StreamSubscription<List<int>>? _stdoutSub;
  final List<int> _buffer = [];
  var _running = false;

  @override
  Stream<Uint8List> get frames => _controller.stream;

  @override
  bool get isRunning => _running;

  @override
  Future<void> start(DisplayLivePreviewConfig config) async {
    if (_running) return;
    if (kIsWeb || !Platform.isLinux) {
      throw LivePreviewCaptureException('live_preview_linux_only');
    }

    final xid = windowXid ?? await _resolveWindowXid?.call();
    if (xid == null) {
      throw LivePreviewCaptureException('live_preview_window_not_found');
    }

    await _startProcess(
      executable: 'gst-launch-1.0',
      args: _gstreamerArgs(xid, config),
      missingCode: 'live_preview_gstreamer_missing',
    );
  }

  List<String> _gstreamerArgs(int xid, DisplayLivePreviewConfig config) {
    return [
      '-q',
      'ximagesrc',
      'window-id=$xid',
      'use-damage=false',
      '!',
      'videoconvert',
      '!',
      'videoscale',
      '!',
      'video/x-raw,width=${config.width}',
      '!',
      'videorate',
      '!',
      'video/x-raw,framerate=${config.fps}/1',
      '!',
      'jpegenc',
      'quality=${config.quality}',
      '!',
      'queue',
      'max-size-buffers=2',
      'leaky=downstream',
      '!',
      'fdsink',
      'fd=1',
      'sync=false',
    ];
  }

  @override
  Future<void> stop() async => _stopProcess();

  Future<void> _startProcess({
    required String executable,
    required List<String> args,
    required String missingCode,
  }) async {
    final env = Map<String, String>.from(Platform.environment);
    env['GST_XINITTHREADS'] = '1';

    try {
      _process = await Process.start(executable, args, environment: env);
    } on ProcessException {
      throw LivePreviewCaptureException(missingCode);
    } on IOException {
      throw LivePreviewCaptureException(missingCode);
    }

    _running = true;
    _stdoutSub = _process!.stdout.listen(
      _onStdoutChunk,
      onError: (_) => _controller.addError(
        LivePreviewCaptureException('live_preview_capture_error'),
      ),
      onDone: () {
        if (_running) {
          _controller.addError(
            LivePreviewCaptureException('live_preview_capture_stopped'),
          );
        }
      },
      cancelOnError: true,
    );
    _process!.stderr.listen((_) {});
  }

  Future<void> _stopProcess() async {
    _running = false;
    await _stdoutSub?.cancel();
    _stdoutSub = null;
    _buffer.clear();
    final proc = _process;
    _process = null;
    if (proc != null) {
      try {
        proc.kill(ProcessSignal.sigterm);
      } catch (_) {}
      try {
        await proc.exitCode.timeout(const Duration(seconds: 2));
      } catch (_) {
        try {
          proc.kill(ProcessSignal.sigkill);
        } catch (_) {}
      }
    }
  }

  void _onStdoutChunk(List<int> chunk) {
    _buffer.addAll(chunk);
    var consumed = 0;
    while (consumed < _buffer.length - 1) {
      if (_buffer[consumed] != 0xFF || _buffer[consumed + 1] != 0xD8) {
        consumed++;
        continue;
      }
      final start = consumed;
      consumed += 2;
      while (consumed < _buffer.length - 1) {
        if (_buffer[consumed] == 0xFF && _buffer[consumed + 1] == 0xD9) {
          consumed += 2;
          if (!_controller.isClosed) {
            _controller.add(Uint8List.fromList(_buffer.sublist(start, consumed)));
          }
          break;
        }
        consumed++;
      }
      if (consumed >= _buffer.length - 1) break;
    }
    if (consumed > 0) {
      _buffer.removeRange(0, consumed);
    }
  }
}

/// ffmpeg x11grab MJPEG pipe fallback when GStreamer is unavailable.
class LinuxFfmpegLivePreviewCapture implements LivePreviewCapture {
  LinuxFfmpegLivePreviewCapture({required this.windowXid});

  final int windowXid;
  final _controller = StreamController<Uint8List>.broadcast();
  Process? _process;
  StreamSubscription<List<int>>? _stdoutSub;
  final List<int> _buffer = [];
  var _running = false;

  @override
  Stream<Uint8List> get frames => _controller.stream;

  @override
  bool get isRunning => _running;

  @override
  Future<void> start(DisplayLivePreviewConfig config) async {
    if (_running) return;
    if (kIsWeb || !Platform.isLinux) {
      throw LivePreviewCaptureException('live_preview_linux_only');
    }

    final qscale = ((100 - config.quality) / 10).round().clamp(2, 31);
    final args = [
      '-hide_banner',
      '-loglevel',
      'error',
      '-f',
      'x11grab',
      '-window_id',
      '0x${windowXid.toRadixString(16)}',
      '-r',
      '${config.fps}',
      '-vf',
      'scale=${config.width}:-2',
      '-q:v',
      '$qscale',
      '-f',
      'image2pipe',
      '-vcodec',
      'mjpeg',
      'pipe:1',
    ];

    try {
      _process = await Process.start('ffmpeg', args);
    } on ProcessException {
      throw LivePreviewCaptureException('live_preview_ffmpeg_missing');
    } on IOException {
      throw LivePreviewCaptureException('live_preview_ffmpeg_missing');
    }

    _running = true;
    _stdoutSub = _process!.stdout.listen(
      _onStdoutChunk,
      onError: (_) => _controller.addError(
        LivePreviewCaptureException('live_preview_capture_error'),
      ),
      onDone: () {
        if (_running) {
          _controller.addError(
            LivePreviewCaptureException('live_preview_capture_stopped'),
          );
        }
      },
      cancelOnError: true,
    );
    _process!.stderr.listen((_) {});
  }

  @override
  Future<void> stop() async {
    _running = false;
    await _stdoutSub?.cancel();
    _stdoutSub = null;
    _buffer.clear();
    final proc = _process;
    _process = null;
    if (proc != null) {
      try {
        proc.kill(ProcessSignal.sigterm);
      } catch (_) {}
      try {
        await proc.exitCode.timeout(const Duration(seconds: 2));
      } catch (_) {
        try {
          proc.kill(ProcessSignal.sigkill);
        } catch (_) {}
      }
    }
  }

  void _onStdoutChunk(List<int> chunk) {
    _buffer.addAll(chunk);
    var consumed = 0;
    while (consumed < _buffer.length - 1) {
      if (_buffer[consumed] != 0xFF || _buffer[consumed + 1] != 0xD8) {
        consumed++;
        continue;
      }
      final start = consumed;
      consumed += 2;
      while (consumed < _buffer.length - 1) {
        if (_buffer[consumed] == 0xFF && _buffer[consumed + 1] == 0xD9) {
          consumed += 2;
          if (!_controller.isClosed) {
            _controller.add(Uint8List.fromList(_buffer.sublist(start, consumed)));
          }
          break;
        }
        consumed++;
      }
      if (consumed >= _buffer.length - 1) break;
    }
    if (consumed > 0) {
      _buffer.removeRange(0, consumed);
    }
  }
}
