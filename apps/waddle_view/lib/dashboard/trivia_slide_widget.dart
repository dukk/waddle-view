import 'dart:async';
import 'dart:math';

import 'package:drift/drift.dart' show CustomExpression, OrderingTerm;
import 'package:flutter/material.dart';

import '../curator/screen_layout_parse.dart';
import '../curator/screen_program_curator.dart';
import '../persistence/database.dart';
import 'trivia_slide_timing.dart';
import 'dashboard_viewport_scope.dart';

Future<TriviaQuestion?> _loadTriviaForSlide(
  AppDatabase db,
  ParsedWidgetSpec spec,
  ResolvedSlide slide,
) async {
  final curatedId = slide.randomChoices[spec.choiceKey];
  if (curatedId != null && curatedId.isNotEmpty) {
    return (db.select(db.triviaQuestions)
          ..where((t) => t.id.equals(curatedId)))
        .getSingleOrNull();
  }
  final categoryId = spec.config['categoryId'] as String?;
  final q = db.select(db.triviaQuestions);
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

/// Source letters A–D assigned to on-screen slots A–D (slot index 0 = label "A.").
@visibleForTesting
List<String> triviaShuffleOrderForTesting(Random random) {
  final letters = ['A', 'B', 'C', 'D']..shuffle(random);
  return List<String>.from(letters);
}

/// Multiple-choice trivia: wrong answers are struck out with an animated X; a
/// progress bar under the question shows time until only the correct answer
/// is emphasized.
class TriviaSlideWidget extends StatefulWidget {
  const TriviaSlideWidget({
    super.key,
    required this.db,
    required this.slide,
    required this.spec,
    required this.theme,
    this.shuffleRandom,
  });

  final AppDatabase db;
  final ResolvedSlide slide;
  final ParsedWidgetSpec spec;
  final ThemeData theme;

  /// When null, a fresh [Random] is used in state. Tests may pass a seeded
  /// instance for deterministic layout.
  final Random? shuffleRandom;

  @override
  State<TriviaSlideWidget> createState() => _TriviaSlideWidgetState();
}

/// Max characters per option (after shuffle mapping) to prefer a 2×2 grid.
@visibleForTesting
const int kTriviaTwoColumnMaxOptionChars = 28;

class _TriviaSlideWidgetState extends State<TriviaSlideWidget> {
  TriviaQuestion? _question;
  bool _loading = true;
  late final Random _rng = widget.shuffleRandom ?? Random();

  /// Index = on-screen slot (0=A, 1=B, …); value = DB option letter for text.
  List<String>? _displaySlotToSource;

  final Set<String> _struckWrong = {};
  List<int> _strikeDelaysMs = [];
  int _eliminationEndMs = 0;
  int _elapsedMs = 0;
  Timer? _tick;
  final List<Timer> _strikeTimers = [];

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    final q = await _loadTriviaForSlide(widget.db, widget.spec, widget.slide);
    if (!mounted) {
      return;
    }
    final perm = q == null ? null : triviaShuffleOrderForTesting(_rng);
    setState(() {
      _question = q;
      _displaySlotToSource = perm;
      _loading = false;
    });
    _startRevealSequence();
  }

  void _startRevealSequence() {
    for (final t in _strikeTimers) {
      t.cancel();
    }
    _strikeTimers.clear();
    _tick?.cancel();
    _struckWrong.clear();
    _strikeDelaysMs = [];
    _elapsedMs = 0;

    final row = _question;
    final perm = _displaySlotToSource;
    if (row == null || perm == null) {
      return;
    }

    final correctSource = row.correctOption.trim().toUpperCase();
    final correctIdx = perm.indexOf(correctSource);
    if (correctIdx < 0) {
      return;
    }
    final displayCorrect =
        String.fromCharCode('A'.codeUnitAt(0) + correctIdx);
    final wrong = <String>['A', 'B', 'C', 'D']
        .where((l) => l != displayCorrect)
        .toList()
      ..shuffle(_rng);

    final override = (widget.spec.config['eliminationWindowMs'] as num?)
        ?.toInt();
    final windowMs = triviaEliminationWindowMs(
      widget.slide.dwellMs,
      configOverride: override,
    );
    _eliminationEndMs = triviaEliminationEndMs(windowMs);
    final step = windowMs ~/ 4;
    final delays = <int>[];

    if (step < 1) {
      for (var i = 0; i < wrong.length; i++) {
        final delayMs =
            (windowMs * (i + 1) ~/ wrong.length).clamp(1, windowMs);
        delays.add(delayMs);
        _strikeTimers.add(
          Timer(Duration(milliseconds: delayMs), () {
            if (!mounted) {
              return;
            }
            setState(() {
              _struckWrong.add(wrong[i]);
            });
          }),
        );
      }
    } else {
      for (var i = 0; i < wrong.length; i++) {
        final delayMs = step * (i + 1);
        delays.add(delayMs);
        _strikeTimers.add(
          Timer(Duration(milliseconds: delayMs), () {
            if (!mounted) {
              return;
            }
            setState(() {
              _struckWrong.add(wrong[i]);
            });
          }),
        );
      }
    }

    setState(() {
      _strikeDelaysMs = delays;
    });

    _tick = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (!mounted) {
        return;
      }
      _elapsedMs += 120;
      if (_elapsedMs >= _eliminationEndMs) {
        _elapsedMs = _eliminationEndMs;
        _tick?.cancel();
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    for (final t in _strikeTimers) {
      t.cancel();
    }
    super.dispose();
  }

  bool _isRevealComplete() =>
      _question != null &&
      _eliminationEndMs > 0 &&
      _elapsedMs >= _eliminationEndMs;

  String _optionText(TriviaQuestion row, String letter) {
    switch (letter) {
      case 'A':
        return row.optionA;
      case 'B':
        return row.optionB;
      case 'C':
        return row.optionC;
      case 'D':
        return row.optionD;
      default:
        return '';
    }
  }

  bool _optionsShortForTwoColumns(TriviaQuestion row, List<String> perm) {
    for (var slot = 0; slot < 4; slot++) {
      if (_optionText(row, perm[slot]).length > kTriviaTwoColumnMaxOptionChars) {
        return false;
      }
    }
    return true;
  }

  Widget _buildRevealProgressBar(ThemeData theme, double s) {
    if (_isRevealComplete() || _eliminationEndMs <= 0) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: EdgeInsets.only(top: 12 * s, bottom: 16 * s),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = 7 * s;
          final remaining =
              (1.0 - _elapsedMs / _eliminationEndMs).clamp(0.0, 1.0);
          final trackColor = theme.colorScheme.surfaceContainerHighest
              .withValues(alpha: 0.55);
          final fillColor =
              theme.colorScheme.primary.withValues(alpha: 0.5);
          final markerColor = theme.colorScheme.onSurfaceVariant;

          return SizedBox(
            key: const ValueKey<String>('trivia_reveal_progress'),
            height: h,
            child: Stack(
              clipBehavior: Clip.none,
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
                for (final delayMs in _strikeDelaysMs)
                  Positioned(
                    left: (delayMs / _eliminationEndMs) * w - 2 * s,
                    top: 0,
                    bottom: 0,
                    width: 4 * s,
                    child: Center(
                      child: Container(
                        width: 4 * s,
                        height: h + 4 * s,
                        decoration: BoxDecoration(
                          color: markerColor,
                          borderRadius: BorderRadius.circular(2 * s),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _optionTile({
    required TriviaQuestion row,
    required List<String> perm,
    required int slot,
    required ThemeData theme,
    required double s,
    required bool revealComplete,
    required bool useTwoColumns,
  }) {
    final displayLetter =
        String.fromCharCode('A'.codeUnitAt(0) + slot);
    final sourceLetter = perm[slot];
    final struck = _struckWrong.contains(displayLetter);
    final correctSource = row.correctOption.trim().toUpperCase();
    final highlight = revealComplete && sourceLetter == correctSource;
    final base = theme.textTheme.titleMedium;
    final TextStyle? optionStyle;
    if (highlight) {
      optionStyle = base?.copyWith(
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.primary,
      );
    } else if (struck) {
      optionStyle = base?.copyWith(
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.62),
      );
    } else {
      optionStyle = base;
    }

    final text = _optionText(row, sourceLetter);

    return Padding(
      padding: EdgeInsets.only(bottom: useTwoColumns ? 0 : 10 * s),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28 * s,
                child: Text(
                  '$displayLetter.',
                  style: optionStyle,
                ),
              ),
              Expanded(
                child: Text(
                  text,
                  style: optionStyle,
                ),
              ),
            ],
          ),
          if (struck)
            Positioned.fill(
              child: TweenAnimationBuilder<double>(
                key: ValueKey<String>('trivia_strike_$displayLetter'),
                duration:
                    const Duration(milliseconds: kTriviaStrikeAnimationMs),
                tween: Tween(begin: 0, end: 1),
                curve: Curves.easeOutCubic,
                builder: (context, t, _) {
                  return CustomPaint(
                    painter: _StrikeXPainter(
                      progress: t,
                      color: theme.colorScheme.error.withValues(alpha: 0.88),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final s = DashboardViewportScope.scaleOf(context);
    if (_loading) {
      return Padding(
        padding: EdgeInsets.all(24 * s),
        child: Center(
          child: SizedBox(
            width: 32 * s,
            height: 32 * s,
            child: const CircularProgressIndicator(),
          ),
        ),
      );
    }
    if (_question == null) {
      return Padding(
        padding: EdgeInsets.only(bottom: 12 * s),
        child: Text(
          'No trivia yet',
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
      );
    }

    final row = _question!;
    final perm = _displaySlotToSource!;
    final revealComplete = _isRevealComplete();
    final useTwoColumns = _optionsShortForTwoColumns(row, perm);

    return LayoutBuilder(
      builder: (context, constraints) {
        final answersSection = useTwoColumns
            ? KeyedSubtree(
                key: const ValueKey<String>('trivia_answers_grid'),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _optionTile(
                            row: row,
                            perm: perm,
                            slot: 0,
                            theme: theme,
                            s: s,
                            revealComplete: revealComplete,
                            useTwoColumns: true,
                          ),
                        ),
                        SizedBox(width: 12 * s),
                        Expanded(
                          child: _optionTile(
                            row: row,
                            perm: perm,
                            slot: 1,
                            theme: theme,
                            s: s,
                            revealComplete: revealComplete,
                            useTwoColumns: true,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10 * s),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _optionTile(
                            row: row,
                            perm: perm,
                            slot: 2,
                            theme: theme,
                            s: s,
                            revealComplete: revealComplete,
                            useTwoColumns: true,
                          ),
                        ),
                        SizedBox(width: 12 * s),
                        Expanded(
                          child: _optionTile(
                            row: row,
                            perm: perm,
                            slot: 3,
                            theme: theme,
                            s: s,
                            revealComplete: revealComplete,
                            useTwoColumns: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            : KeyedSubtree(
                key: const ValueKey<String>('trivia_answers_column'),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(4, (slot) {
                    return _optionTile(
                      row: row,
                      perm: perm,
                      slot: slot,
                      theme: theme,
                      s: s,
                      revealComplete: revealComplete,
                      useTwoColumns: false,
                    );
                  }),
                ),
              );

        final column = Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: min(constraints.maxWidth, 720 * s),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  row.question,
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                _buildRevealProgressBar(theme, s),
                answersSection,
              ],
            ),
          ),
        );
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;
        if (maxH.isFinite) {
          return SizedBox(width: maxW, height: maxH, child: column);
        }
        return SizedBox(width: maxW, child: column);
      },
    );
  }
}

class _StrikeXPainter extends CustomPainter {
  _StrikeXPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) {
      return;
    }
    final stroke = max(2.0, size.shortestSide * 0.06);
    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final pad = stroke;
    final rect = Rect.fromLTWH(
      pad,
      pad,
      size.width - 2 * pad,
      size.height - 2 * pad,
    );
    final t = progress;

    final end1 = Offset.lerp(rect.topLeft, rect.bottomRight, t)!;
    canvas.drawLine(rect.topLeft, end1, paint);

    final end2 = Offset.lerp(rect.topRight, rect.bottomLeft, t)!;
    canvas.drawLine(rect.topRight, end2, paint);
  }

  @override
  bool shouldRepaint(covariant _StrikeXPainter old) =>
      old.progress != progress || old.color != color;
}
