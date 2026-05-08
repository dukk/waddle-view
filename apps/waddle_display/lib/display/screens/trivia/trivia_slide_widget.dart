import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../blob/blob_store.dart';
import '../../../curator/screen_layout_parse.dart';
import '../../../curator/screen_program_curator.dart';
import '../../../persistence/database.dart';
import '../../../theme/theme_palette_extension.dart';
import '../../content_category_slide_header.dart';
import '../../dashboard_viewport_scope.dart';
import '../../slide_content_joke_trivia.dart';
import 'trivia_slide_timing.dart';

/// Source letters A–D assigned to on-screen slots A–D (slot index 0 = on-screen "A").
@visibleForTesting
List<String> triviaShuffleOrderForTesting(Random random) {
  final letters = ['A', 'B', 'C', 'D']..shuffle(random);
  return List<String>.from(letters);
}

/// Multiple-choice trivia: wrong answers strike out; a progress bar (like [JokeSlideWidget])
/// counts down until the correct answer is emphasized.
class TriviaSlideWidget extends StatefulWidget {
  const TriviaSlideWidget({
    super.key,
    required this.db,
    required this.blobs,
    required this.slide,
    required this.spec,
    required this.theme,
    this.shuffleRandom,
  });

  final AppDatabase db;
  final BlobStore blobs;
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
    final q = await loadTriviaForSlide(widget.db, widget.spec, widget.slide);
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

  /// Same layout pattern as [JokeSlideWidget._buildPunchlineProgressBar], plus strike tick marks.
  Widget _buildRevealProgressBar(ThemeData theme, double s) {
    if (_eliminationEndMs <= 0) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: EdgeInsets.only(top: 12 * s, bottom: 16 * s),
      child: Align(
        alignment: Alignment.center,
        child: FractionallySizedBox(
          widthFactor: 0.55,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = 7 * s;
              final remaining =
                  (1.0 - _elapsedMs / _eliminationEndMs).clamp(0.0, 1.0);
              final trackColor = theme.colorScheme.secondaryContainer
                  .withValues(alpha: 0.55);
              final fillColor =
                  theme.colorScheme.secondary.withValues(alpha: 0.5);
              final markerColor = theme.colorScheme.secondary;

              return SizedBox(
                key: const ValueKey<String>('trivia_reveal_progress'),
                height: h,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Stack(
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
        ),
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
    final cs = theme.colorScheme;
    final palette = theme.extension<PaletteTertiaryLayers>();
    final accentColors = [
      palette?.accent1 ?? cs.secondary,
      palette?.accent2 ?? cs.tertiary,
      palette?.accent3 ?? cs.primary,
      palette?.accent1 ?? cs.secondary,
    ];
    final accentColor = accentColors[slot % accentColors.length];
    final normalTextColor = cs.onSurface;
    final base = theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final TextStyle? optionStyle;
    if (highlight) {
      optionStyle = base?.copyWith(
        fontWeight: FontWeight.w700,
        color: normalTextColor,
        height: 1.25,
      );
    } else {
      optionStyle = base?.copyWith(
        color: normalTextColor,
        height: 1.25,
      );
    }

    final badgeStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w800,
      color: cs.onPrimary,
      height: 1.0,
      leadingDistribution: TextLeadingDistribution.even,
    );

    final text = _optionText(row, sourceLetter);
    final badgeDiameter = 36 * s;
    final badgeFill = accentColor.withValues(alpha: struck ? 0.45 : 1.0);
    final badgeLetterColor =
        struck ? cs.onSurface.withValues(alpha: 0.65) : cs.onPrimary;

    return Padding(
      padding: EdgeInsets.only(bottom: useTwoColumns ? 0 : 10 * s),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 6 * s, horizontal: 4 * s),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: badgeDiameter,
                  height: badgeDiameter,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: badgeFill,
                  ),
                  child: Text(
                    displayLetter,
                    textAlign: TextAlign.center,
                    style: badgeStyle?.copyWith(color: badgeLetterColor),
                    textHeightBehavior: const TextHeightBehavior(
                      applyHeightToFirstAscent: false,
                      applyHeightToLastDescent: false,
                    ),
                  ),
                ),
                SizedBox(width: 12 * s),
                Expanded(
                  child: Text(
                    text,
                    style: optionStyle,
                    softWrap: true,
                    textAlign: TextAlign.start,
                  ),
                ),
              ],
            ),
          ),
          if (struck)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8 * s),
                ),
              ),
            ),
          if (struck)
            Positioned(
              right: 4 * s,
              top: 0,
              bottom: 0,
              child: Center(
                child: TweenAnimationBuilder<double>(
                  key: ValueKey<String>('trivia_strike_$displayLetter'),
                  duration:
                      const Duration(milliseconds: kTriviaStrikeAnimationMs),
                  tween: Tween(begin: 0, end: 1),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, _) {
                    return Opacity(
                      opacity: t,
                      child: Transform.scale(
                        scale: 0.82 + (0.18 * t),
                        child: Container(
                          padding: EdgeInsets.all(5 * s),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close,
                            key: ValueKey<String>(
                              'trivia_close_icon_$displayLetter',
                            ),
                            color: const Color(0xFFFF5252),
                            size: 24 * s,
                          ),
                        ),
                      ),
                    );
                  },
                ),
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
    final cfgCat = widget.spec.config['categoryId'] as String?;
    final headerCat = (cfgCat != null && cfgCat.isNotEmpty)
        ? cfgCat
        : _question?.categoryId;

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
    if (_question == null) {
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
              'No trivia yet',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    final row = _question!;
    final perm = _displaySlotToSource!;
    final revealComplete = _isRevealComplete();
    final useTwoColumns = _optionsShortForTwoColumns(row, perm);

    final answersSection = useTwoColumns
        ? KeyedSubtree(
            key: const ValueKey<String>('trivia_answers_grid'),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                SizedBox(height: 8 * s),
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
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

    return Padding(
      padding: EdgeInsets.only(bottom: 12 * s),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ContentCategorySlideHeader(
            db: widget.db,
            blobs: widget.blobs,
            theme: theme,
            categoryId: headerCat,
          ),
          Text(
            row.question,
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
            softWrap: true,
          ),
          _buildRevealProgressBar(theme, s),
          answersSection,
        ],
      ),
    );
  }
}
