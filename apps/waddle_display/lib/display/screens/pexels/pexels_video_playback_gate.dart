import 'dart:async';

import 'package:flutter/foundation.dart';

/// Serializes media_kit [Player] create/dispose across all Pexels video slides.
///
/// Signage shows one slide at a time, but slide transitions and widget rebuilds
/// can overlap native texture teardown with the next player. On embedded Linux
/// (e.g. Raspberry Pi) that leaves MESA buffer objects allocated until the
/// process segfaults.
final class PexelsVideoPlaybackGate {
  PexelsVideoPlaybackGate._();

  static final PexelsVideoPlaybackGate instance = PexelsVideoPlaybackGate._();

  Future<void> _tail = Future<void>.value();

  @visibleForTesting
  void resetForTest() {
    _tail = Future<void>.value();
  }

  Future<T> run<T>(Future<T> Function() action) {
    final previous = _tail;
    final done = Completer<void>();
    _tail = done.future;
    return previous.then((_) => action()).whenComplete(() {
      if (!done.isCompleted) {
        done.complete();
      }
    });
  }
}
