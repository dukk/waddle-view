import 'dart:async';

import 'package:drift/drift.dart' show CustomExpression, OrderingTerm;
import 'package:flutter/material.dart';

import '../blob/blob_store.dart';
import '../curator/screen_layout_parse.dart';
import '../curator/screen_program_curator.dart';
import '../persistence/database.dart';
import 'content_category_slide_header.dart';
import 'joke_slide_timing.dart';
import 'dashboard_viewport_scope.dart';

/// Curated joke id from [slide], else random from [db] (optional [categoryId]).
Future<Joke?> _loadJokeForSlide(
  AppDatabase db,
  ParsedWidgetSpec spec,
  ResolvedSlide slide,
) async {
  final curatedId = slide.randomChoices[spec.choiceKey];
  if (curatedId != null && curatedId.isNotEmpty) {
    return (db.select(db.jokes)..where((t) => t.id.equals(curatedId)))
        .getSingleOrNull();
  }
  final categoryId = spec.config['categoryId'] as String?;
  final q = db.select(db.jokes);
  if (categoryId != null && categoryId.isNotEmpty) {
    q.where((t) => t.categoryId.equals(categoryId));
  }
  return (q
        ..orderBy([
          (t) => OrderingTerm(expression: const CustomExpression('random()')),
        ])
        ..limit(1))
      .getSingleOrNull();
}

/// Shows joke setup, then punchline after half of [slide.dwellMs].
class JokeSlideWidget extends StatefulWidget {
  const JokeSlideWidget({
    super.key,
    required this.db,
    required this.blobs,
    required this.slide,
    required this.spec,
    required this.theme,
  });

  final AppDatabase db;
  final BlobStore blobs;
  final ResolvedSlide slide;
  final ParsedWidgetSpec spec;
  final ThemeData theme;

  @override
  State<JokeSlideWidget> createState() => _JokeSlideWidgetState();
}

class _JokeSlideWidgetState extends State<JokeSlideWidget> {
  Joke? _joke;
  bool _loading = true;
  bool _showPunchline = false;
  int _punchlineDelayMs = 0;
  int _elapsedMs = 0;
  Timer? _punchlineTimer;
  Timer? _progressTick;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    final joke = await _loadJokeForSlide(widget.db, widget.spec, widget.slide);
    if (!mounted) {
      return;
    }
    setState(() {
      _joke = joke;
      _loading = false;
    });
    _schedulePunchlineReveal();
  }

  void _schedulePunchlineReveal() {
    _punchlineTimer?.cancel();
    _progressTick?.cancel();
    if (_joke == null) {
      return;
    }
    final delayMs = punchlineDelayMs(widget.slide.dwellMs);
    _punchlineDelayMs = delayMs;
    _elapsedMs = 0;
    if (delayMs <= 0) {
      setState(() {
        _showPunchline = true;
      });
      return;
    }
    _progressTick = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (!mounted) {
        return;
      }
      _elapsedMs += 120;
      if (_elapsedMs >= _punchlineDelayMs) {
        _elapsedMs = _punchlineDelayMs;
        _progressTick?.cancel();
      }
      setState(() {});
    });
    _punchlineTimer = Timer(Duration(milliseconds: delayMs), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _elapsedMs = _punchlineDelayMs;
        _showPunchline = true;
      });
    });
  }

  Widget _buildPunchlineProgressBar(ThemeData theme, double s) {
    if (_punchlineDelayMs <= 0) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: EdgeInsets.only(top: 12 * s, bottom: 16 * s),
      child: Align(
        alignment: Alignment.center,
        child: FractionallySizedBox(
          widthFactor: 0.5,
          child: Builder(
            builder: (context) {
              final h = 7 * s;
              final remaining =
                  (1.0 - _elapsedMs / _punchlineDelayMs).clamp(0.0, 1.0);
              final trackColor = theme.colorScheme.secondaryContainer
                  .withValues(alpha: 0.55);
              final fillColor =
                  theme.colorScheme.secondary.withValues(alpha: 0.5);
              return SizedBox(
                key: const ValueKey<String>('joke_punchline_progress'),
                height: h,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: trackColor,
                        borderRadius: BorderRadius.circular(4 * s),
                      ),
                    ),
                    Positioned.fill(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: remaining,
                          alignment: Alignment.centerLeft,
                          child: Container(
                            decoration: BoxDecoration(
                              color: fillColor,
                              borderRadius: BorderRadius.circular(4 * s),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _punchlineTimer?.cancel();
    _progressTick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final s = DashboardViewportScope.scaleOf(context);
    final cfgCat = widget.spec.config['categoryId'] as String?;
    final headerCat = (cfgCat != null && cfgCat.isNotEmpty)
        ? cfgCat
        : _joke?.categoryId;

    if (_loading) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ContentCategorySlideHeader(
            db: widget.db,
            blobs: widget.blobs,
            theme: theme,
            categoryId: cfgCat,
          ),
          Padding(
            padding: EdgeInsets.all(24 * s),
            child: Center(
              child: SizedBox(
                width: 32 * s,
                height: 32 * s,
                child: const CircularProgressIndicator(),
              ),
            ),
          ),
        ],
      );
    }
    if (_joke == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ContentCategorySlideHeader(
            db: widget.db,
            blobs: widget.blobs,
            theme: theme,
            categoryId: headerCat,
          ),
          Padding(
            padding: EdgeInsets.only(bottom: 12 * s),
            child: Text(
              'No jokes yet',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: 12 * s),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ContentCategorySlideHeader(
            db: widget.db,
            blobs: widget.blobs,
            theme: theme,
            categoryId: headerCat,
          ),
          Text(
            _joke!.setup,
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          _buildPunchlineProgressBar(theme, s),
          AnimatedOpacity(
            opacity: _showPunchline ? 1 : 0,
            duration: const Duration(milliseconds: 320),
            child: Text(
              _joke!.punchline,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
