import 'dart:async';

import 'package:flutter/material.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';

import '../../../curator/screen_program_curator.dart';
import '../rss_article/rss_article_slide_timing.dart';
import 'web_page_config.dart';
import 'web_page_session.dart';

/// Full-bleed embedded web page. Expects [WebPagePrepareCache] to have finished
/// loading before this widget is shown; otherwise shows a brief error state.
class WebPageSlideWidget extends StatefulWidget {
  const WebPageSlideWidget({
    super.key,
    required this.slide,
    required this.spec,
    required this.onReportDesiredDwell,
  });

  final ResolvedSlide slide;
  final ParsedWidgetSpec spec;
  final void Function(int desiredDwellMs) onReportDesiredDwell;

  @override
  State<WebPageSlideWidget> createState() => _WebPageSlideWidgetState();
}

class _WebPageSlideWidgetState extends State<WebPageSlideWidget> {
  WebPagePreparedSession? _session;
  String? _error;
  Timer? _scrollDelayTimer;
  Timer? _scrollTickTimer;
  bool _dwellReported = false;

  static const _minReadMs = 4000;
  static const _scrollTickMs = 50;

  @override
  void initState() {
    super.initState();
    _attachSession();
  }

  void _attachSession() {
    final config = parseWebPageConfig(widget.spec.config);
    if (config.uri == null ||
        (config.uri!.scheme != 'http' && config.uri!.scheme != 'https')) {
      _error = 'Invalid or missing config.url (http/https required)';
      return;
    }
    final session = WebPagePrepareCache.instance.takeReady(widget.spec);
    if (session == null) {
      _error = 'Web page was not preloaded';
      return;
    }
    _session = session;
    WidgetsBinding.instance.addPostFrameCallback((_) => _planDwellAndScroll());
  }

  Future<void> _planDwellAndScroll() async {
    final session = _session;
    if (session == null || !mounted) {
      return;
    }
    final config = session.config;
    final scrollCfg = config.autoScroll;
    var maxExtent = 0.0;
    if (scrollCfg.enabled) {
      try {
        maxExtent = await session.measureScrollableExtent();
      } catch (_) {
        maxExtent = 0;
      }
    }
    final scrollable = scrollCfg.enabled && maxExtent > 8;
    final desired = desiredDwellMsForRssArticle(
      baseDwellMs: widget.slide.dwellMs,
      minReadMs: _minReadMs,
      summaryScrollable: scrollable,
      scrollDelayMs: scrollCfg.delayMs,
      trailingHoldMs: scrollCfg.trailingHoldMs,
      maxScrollExtent: maxExtent,
      scrollPixelsPerSecond: scrollCfg.pixelsPerSecond,
    );
    if (!_dwellReported && mounted) {
      _dwellReported = true;
      widget.onReportDesiredDwell(desired);
    }
    if (!scrollable || !mounted) {
      return;
    }
    _scrollDelayTimer = Timer(Duration(milliseconds: scrollCfg.delayMs), () {
      if (!mounted) {
        return;
      }
      final deltaPerTick =
          scrollCfg.pixelsPerSecond * (_scrollTickMs / 1000.0);
      var scrolled = 0.0;
      _scrollTickTimer = Timer.periodic(
        const Duration(milliseconds: _scrollTickMs),
        (timer) async {
          if (!mounted) {
            timer.cancel();
            return;
          }
          if (scrolled >= maxExtent) {
            timer.cancel();
            return;
          }
          final step = (scrolled + deltaPerTick > maxExtent)
              ? (maxExtent - scrolled)
              : deltaPerTick;
          scrolled += step;
          try {
            await session.scrollBy(step);
          } catch (_) {
            timer.cancel();
          }
        },
      );
    });
  }

  @override
  void dispose() {
    _scrollDelayTimer?.cancel();
    _scrollTickTimer?.cancel();
    _session?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      );
    }
    final session = _session;
    if (session == null) {
      return const SizedBox.shrink();
    }
    return session.buildView();
  }
}
