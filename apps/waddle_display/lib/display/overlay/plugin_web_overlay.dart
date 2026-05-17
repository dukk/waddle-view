import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:waddle_shared/persistence/display_overlay_schedule_row.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Transparent web layer for plugin overlays (`config_json.url`).
class PluginWebOverlay extends StatefulWidget {
  const PluginWebOverlay({super.key, required this.row});

  final DisplayOverlayScheduleRow row;

  @override
  State<PluginWebOverlay> createState() => _PluginWebOverlayState();
}

class _PluginWebOverlayState extends State<PluginWebOverlay> {
  WebViewController? _controller;

  @override
  void initState() {
    super.initState();
    final config = _parseConfig(widget.row.configJson);
    final url = (config['url'] as String?)?.trim() ?? '';
    if (url.isNotEmpty) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000))
        ..loadRequest(Uri.parse(url));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c == null) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: WebViewWidget(controller: c),
    );
  }

  Map<String, dynamic> _parseConfig(String raw) {
    if (raw.trim().isEmpty) {
      return const {};
    }
    try {
      final v = jsonDecode(raw);
      if (v is Map<String, dynamic>) {
        return v;
      }
    } on Object {
      // ignore
    }
    return const {};
  }
}
