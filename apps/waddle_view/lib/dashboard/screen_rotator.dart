import 'dart:async';
import 'dart:math';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';

import '../curator/screen_layout_parse.dart';
import '../curator/screen_program_curator.dart';
import '../persistence/database.dart';
import '../persistence/tables.dart';
import 'guest_wifi_slide_widget.dart';
import 'joke_slide_widget.dart';

/// Full-area carousel above the ticker: slides exit left / enter right between
/// curated programs loaded from `screen_definitions` and `curator_settings`.
class ScreenRotator extends StatefulWidget {
  const ScreenRotator({super.key, required this.db});

  final AppDatabase db;

  @override
  State<ScreenRotator> createState() => _ScreenRotatorState();
}

class _ScreenRotatorState extends State<ScreenRotator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _anim,
    curve: Curves.easeInOutCubic,
  );

  final _random = Random();
  final List<String> _recentScreenIds = [];

  List<ResolvedSlide> _program = const [];
  int _index = 0;
  ResolvedSlide? _fromSlide;
  ResolvedSlide? _toSlide;
  Timer? _dwellTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    _dwellTimer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _startNewProgram();
  }

  Future<void> _startNewProgram() async {
    final defs = await (widget.db.select(widget.db.screenDefinitions)
          ..where((t) => t.enabled.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
    final set =
        await (widget.db.select(widget.db.curatorSettings)
              ..where((t) => t.id.equals(kCuratorSettingsId)))
            .getSingleOrNull();
    final programMs = set?.programDurationMs ?? 180000;
    final historyDepth = set?.historyDepth ?? 5;

    final blobs = await widget.db.select(widget.db.blobMetadata).get();
    final pools = <String, List<String>>{
      if (blobs.isNotEmpty) 'blobs': blobs.map((e) => e.blobKey).toList(),
    };

    final candidates = defs
        .map(
          (r) => ScreenCandidate(
            id: r.id,
            dwellMs: r.dwellMs,
            frequencyWeight: r.frequencyWeight,
            minGapBetweenShowsMs: r.minGapBetweenShowsMs,
            layoutJson: r.layoutJson,
            enabled: r.enabled,
          ),
        )
        .toList();

    final program = ScreenProgramCurator.buildProgram(
      screens: candidates,
      programDurationMs: programMs,
      recentScreenIdsOldestFirst: List<String>.from(_recentScreenIds),
      historyDepth: historyDepth,
      random: _random,
      randomPools: pools,
    );

    if (!mounted) {
      return;
    }
    setState(() {
      _program = program;
      _index = 0;
      _fromSlide = null;
      _toSlide = program.isEmpty ? null : program.first;
    });
    _scheduleDwellForCurrentSlide();
  }

  void _scheduleDwellForCurrentSlide() {
    _dwellTimer?.cancel();
    if (_program.isEmpty || _toSlide == null) {
      return;
    }
    final slide = _program[_index];
    _dwellTimer = Timer(Duration(milliseconds: slide.dwellMs), _onDwellElapsed);
  }

  Future<void> _onDwellElapsed() async {
    if (!mounted || _program.isEmpty) {
      return;
    }
    final slide = _program[_index];
    _recentScreenIds.add(slide.screenId);
    while (_recentScreenIds.length > 200) {
      _recentScreenIds.removeAt(0);
    }

    final nextIndex = _index + 1;
    if (nextIndex >= _program.length) {
      await _startNewProgram();
      return;
    }

    final next = _program[nextIndex];
    setState(() {
      _fromSlide = slide;
      _toSlide = next;
      _index = nextIndex;
    });
    _anim.forward(from: 0).then((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _fromSlide = null;
      });
      _scheduleDwellForCurrentSlide();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outgoing = _fromSlide;
    final incoming = _toSlide ?? outgoing;

    if (_program.isEmpty) {
      return Center(
        child: Text(
          'No display screens enabled',
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
      );
    }

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (outgoing != null && incoming != null && outgoing != incoming)
            SlideTransition(
              position: Tween<Offset>(
                begin: Offset.zero,
                end: const Offset(-1, 0),
              ).animate(_curve),
              child: _SlideContent(
                db: widget.db,
                slide: outgoing,
                theme: theme,
              ),
            ),
          SlideTransition(
            position: Tween<Offset>(
              begin: outgoing != null && outgoing != incoming
                  ? const Offset(1, 0)
                  : Offset.zero,
              end: Offset.zero,
            ).animate(_curve),
            child: incoming != null
                ? _SlideContent(
                    db: widget.db,
                    slide: incoming,
                    theme: theme,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _SlideContent extends StatelessWidget {
  const _SlideContent({
    required this.db,
    required this.slide,
    required this.theme,
  });

  final AppDatabase db;
  final ResolvedSlide slide;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final widgets = parseScreenLayoutWidgets(slide.layoutJson);
    return Container(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: _buildWidgets(widgets, slide),
      ),
    );
  }

  Widget _buildWidgets(List<ParsedWidgetSpec> widgets, ResolvedSlide slide) {
    if (widgets.isEmpty) {
      return Text(
        'Empty layout',
        style: theme.textTheme.bodyLarge,
        textAlign: TextAlign.center,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: widgets.map((w) {
        switch (w.type) {
          case 'static_text':
            final text = w.config['text'] as String? ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                text,
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
            );
          case 'joke':
            return JokeSlideWidget(
              db: db,
              slide: slide,
              spec: w,
              theme: theme,
            );
          case 'guest_wifi':
            return GuestWifiSlideWidget(
              db: db,
              spec: w,
              theme: theme,
            );
          case 'photo_random':
            final key = slide.randomChoices[w.choiceKey];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                key != null ? 'Photo: $key' : 'No photo in pool',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            );
          default:
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Unknown widget: ${w.type}',
                style: theme.textTheme.bodyMedium,
              ),
            );
        }
      }).toList(),
    );
  }
}
