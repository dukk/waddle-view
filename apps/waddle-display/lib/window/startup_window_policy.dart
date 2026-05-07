import 'package:meta/meta.dart';

/// Pure policy for when to maximize / fullscreen the embedder window.
@immutable
class StartupWindowPolicy {
  const StartupWindowPolicy({
    required this.isLinux,
    required this.isDebug,
    required this.allowFullscreen,
  });

  final bool isLinux;
  final bool isDebug;
  final bool allowFullscreen;

  bool get shouldMaximize => isLinux && allowFullscreen && !isDebug;
}
