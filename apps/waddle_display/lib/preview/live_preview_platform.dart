import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'live_preview_boundary.dart';
import 'live_preview_capture.dart';
import 'live_preview_capture_backend.dart';
import 'linux_desktop_live_preview_capture.dart';
import 'widget_live_preview_capture.dart';

/// Selects capture backend for the current platform.
LivePreviewCapture createPlatformLivePreviewCapture({GlobalKey? boundaryKey}) {
  if (!kIsWeb && Platform.isLinux) {
    return LinuxDesktopLivePreviewCapture();
  }
  if (!kIsWeb && (Platform.isWindows || Platform.isMacOS)) {
    livePreviewActiveBackend = LivePreviewCaptureBackend.widget;
    return WidgetLivePreviewCapture(
      boundaryKey: boundaryKey ?? livePreviewBoundaryKey,
    );
  }
  livePreviewActiveBackend = LivePreviewCaptureBackend.testPattern;
  return TestPatternLivePreviewCapture();
}
