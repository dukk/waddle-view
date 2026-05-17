class PluginTemplateOverlayState {
  const PluginTemplateOverlayState({
    this.opacity = 0.35,
    this.messages = const [],
  });

  final double opacity;
  final List<String> messages;

  Map<String, dynamic> toJson() => {
        'v': 1,
        'opacity': opacity,
        'messages': messages,
      };
}
