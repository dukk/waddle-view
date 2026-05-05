import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show CustomExpression, OrderingTerm;
import 'package:flutter/material.dart';

import '../curator/screen_layout_parse.dart';
import '../curator/screen_program_curator.dart';
import '../persistence/database.dart';
import 'trivia_slide_timing.dart';

Future<TriviaQuestion?> _loadRandomTrivia(
  AppDatabase db,
  ParsedWidgetSpec spec,
) async {
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

/// Multiple-choice trivia: wrong answers fade out; countdown until only the
/// correct answer remains visible.
class TriviaSlideWidget extends StatefulWidget {
  const TriviaSlideWidget({
    super.key,
    required this.db,
    required this.slide,
    required this.spec,
    required this.theme,
  });

  final AppDatabase db;
  final ResolvedSlide slide;
  final ParsedWidgetSpec spec;
  final ThemeData theme;

  @override
  State<TriviaSlideWidget> createState() => _TriviaSlideWidgetState();
}

class _TriviaSlideWidgetState extends State<TriviaSlideWidget> {
  TriviaQuestion? _question;
  bool _loading = true;

  final Set<String> _fadingWrong = {};
  final Stopwatch _stopwatch = Stopwatch();
  int _eliminationEndMs = 0;
  Timer? _tick;
  final List<Timer> _fadeTimers = [];

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    final q = await _loadRandomTrivia(widget.db, widget.spec);
    if (!mounted) {
      return;
    }
    setState(() {
      _question = q;
      _loading = false;
    });
    _startRevealSequence();
  }

  void _startRevealSequence() {
    for (final t in _fadeTimers) {
      t.cancel();
    }
    _fadeTimers.clear();
    _tick?.cancel();
    _fadingWrong.clear();
    _stopwatch.reset();

    final row = _question;
    if (row == null) {
      return;
    }

    final correct = row.correctOption.trim().toUpperCase();
    final wrong = <String>['A', 'B', 'C', 'D']
        .where((l) => l != correct)
        .toList()
      ..shuffle(Random());

    final override = (widget.spec.config['eliminationWindowMs'] as num?)
        ?.toInt();
    final windowMs = triviaEliminationWindowMs(
      widget.slide.dwellMs,
      configOverride: override,
    );
    _eliminationEndMs = triviaEliminationEndMs(windowMs);
    final step = windowMs ~/ 4;
    if (step < 1) {
      for (var i = 0; i < wrong.length; i++) {
        final delayMs = (windowMs * (i + 1) ~/ wrong.length).clamp(1, windowMs);
        _fadeTimers.add(
          Timer(Duration(milliseconds: delayMs), () {
            if (!mounted) {
              return;
            }
            setState(() {
              _fadingWrong.add(wrong[i]);
            });
          }),
        );
      }
    } else {
      for (var i = 0; i < wrong.length; i++) {
        final delayMs = step * (i + 1);
        _fadeTimers.add(
          Timer(Duration(milliseconds: delayMs), () {
            if (!mounted) {
              return;
            }
            setState(() {
              _fadingWrong.add(wrong[i]);
            });
          }),
        );
      }
    }

    _stopwatch.start();
    _tick = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (!mounted) {
        return;
      }
      if (_stopwatch.elapsedMilliseconds >= _eliminationEndMs) {
        _tick?.cancel();
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    for (final t in _fadeTimers) {
      t.cancel();
    }
    super.dispose();
  }

  int _countdownSeconds() {
    if (_question == null || !_stopwatch.isRunning) {
      return 0;
    }
    final elapsed = _stopwatch.elapsedMilliseconds;
    final remaining = _eliminationEndMs - elapsed;
    if (remaining <= 0) {
      return 0;
    }
    return (remaining + 999) ~/ 1000;
  }

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

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }
    if (_question == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          'No trivia yet',
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
      );
    }

    final row = _question!;
    final letters = ['A', 'B', 'C', 'D'];
    final countdown = _countdownSeconds();

    return LayoutBuilder(
      builder: (context, constraints) {
        // #region agent log
        try {
          File(r'c:\dev\waddle-view\debug-3162c3.log').writeAsStringSync(
            '${jsonEncode({
              'sessionId': '3162c3',
              'hypothesisId': 'H1',
              'location': 'trivia_slide_widget.dart:LayoutBuilder',
              'message': 'trivia layout constraints',
              'data': {
                'maxWidth': constraints.maxWidth,
                'maxHeight': constraints.maxHeight,
                'hasBoundedHeight': constraints.hasBoundedHeight,
                'minHeight': constraints.minHeight,
              },
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            })}\n',
            mode: FileMode.append,
          );
        } catch (_) {}
        // #endregion
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 0,
                right: 0,
                child: Text(
                  '$countdown',
                  key: const ValueKey<String>('trivia_countdown'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: min(constraints.maxWidth, 720),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        row.question,
                        style: theme.textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ...letters.map((letter) {
                        final hidden = _fadingWrong.contains(letter);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: AnimatedOpacity(
                            opacity: hidden ? 0 : 1,
                            duration: const Duration(
                              milliseconds: kTriviaWrongAnswerFadeMs,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 28,
                                  child: Text(
                                    '$letter.',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    _optionText(row, letter),
                                    style: theme.textTheme.titleMedium,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
