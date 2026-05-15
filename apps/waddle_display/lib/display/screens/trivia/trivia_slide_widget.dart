import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'package:waddle_shared/blob/blob_store.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import '../../../curator/screen_program_curator.dart';
import 'package:waddle_shared/persistence/database.dart';
import '../../../theme/theme_palette_extension.dart';
import '../../content_category_slide_header.dart';
import '../../dashboard_viewport_scope.dart';
import '../../slide_content_joke_trivia.dart';
import 'trivia_slide_timing.dart';
import 'trivia_strike_animation.dart';

/// Source letters A–D assigned to on-screen slots A–D (slot index 0 = on-screen "A").
@visibleForTesting
List<String> triviaShuffleOrderForTesting(
  Random random, {
  int optionCount = 4,
}) {
  final letters = ['A', 'B', 'C', 'D'].take(optionCount).toList()
    ..shuffle(random);
  return List<String>.from(letters);
}

Color _readableOnStripe(Color background) {
  return background.computeLuminance() > 0.42
      ? const Color(0xFF0D1B2A)
      : const Color(0xFFE0E1DD);
}

/// Multiple-choice trivia: wrong answers strike out; a progress bar (like [JokeSlideWidget])
/// counts down until elimination completes.
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

/// Smallest row height for the letter stripe and text stack (matches tile layout).
double _triviaOptionRowMinHeight(double s) => 52.0 * s;

/// Uniform option row height so every tile matches the largest text need, for a
/// given inner Row width (tile width minus horizontal tile inset, 12×[s] total).
@visibleForTesting
double triviaUniformOptionRowHeightForTesting({
  required double innerRowWidth,
  required List<String> optionTexts,
  required TextStyle? optionStyle,
  required TextScaler textScaler,
  required double s,
}) {
  final textPadH = 40.0 * s;
  final textPadV = 24.0 * s;
  final minR = _triviaOptionRowMinHeight(s);
  if (innerRowWidth <= textPadH + minR + 1) {
    return minR;
  }
  var r = minR;
  for (var iter = 0; iter < 48; iter++) {
    final textMaxW = (innerRowWidth - r - textPadH).clamp(1.0, innerRowWidth);
    var maxNeed = minR;
    for (final t in optionTexts) {
      final painter = TextPainter(
        text: TextSpan(text: t, style: optionStyle),
        textDirection: TextDirection.ltr,
        maxLines: null,
        textScaler: textScaler,
      )..layout(maxWidth: textMaxW);
      final need = painter.height + textPadV;
      if (need > maxNeed) {
        maxNeed = need;
      }
    }
    if (maxNeed <= r + 0.5) {
      return r;
    }
    if (maxNeed >= innerRowWidth - textPadH - 1) {
      return (innerRowWidth - textPadH - 1).clamp(minR, innerRowWidth);
    }
    r = maxNeed;
  }
  return r;
}

/// Inner Row width (letter square + text) and row height: width is shrunk from
/// [maxInnerRowWidth] while all options stay legible, matching the same padding
/// and typography as the tile.
@visibleForTesting
({double innerRowWidth, double rowHeight}) triviaUniformOptionGeometryForTesting({
  required double maxInnerRowWidth,
  required List<String> optionTexts,
  required TextStyle? optionStyle,
  required TextScaler textScaler,
  required double s,
}) {
  final textPadH = 40.0 * s;
  final minR = _triviaOptionRowMinHeight(s);
  final minInner = minR + textPadH + 8;
  var innerW = maxInnerRowWidth.clamp(minInner, double.infinity);
  for (var iter = 0; iter < 40; iter++) {
    final h = triviaUniformOptionRowHeightForTesting(
      innerRowWidth: innerW,
      optionTexts: optionTexts,
      optionStyle: optionStyle,
      textScaler: textScaler,
      s: s,
    );
    final wText = innerW - h - textPadH;
    if (wText < 1) {
      innerW = maxInnerRowWidth;
      break;
    }
    var maxUsed = 1.0;
    for (final t in optionTexts) {
      final painter = TextPainter(
        text: TextSpan(text: t, style: optionStyle),
        textDirection: TextDirection.ltr,
        maxLines: null,
        textScaler: textScaler,
      )..layout(maxWidth: wText);
      maxUsed = max(maxUsed, painter.width);
    }
    final needInner = h + textPadH + maxUsed;
    if ((needInner - innerW).abs() < 0.5) {
      return (innerRowWidth: innerW, rowHeight: h);
    }
    innerW = needInner.clamp(minInner, maxInnerRowWidth);
  }
  final hFinal = triviaUniformOptionRowHeightForTesting(
    innerRowWidth: innerW,
    optionTexts: optionTexts,
    optionStyle: optionStyle,
    textScaler: textScaler,
    s: s,
  );
  return (innerRowWidth: innerW, rowHeight: hFinal);
}

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
  TriviaStrikeAnimationKind _strikeAnimationKind =
      TriviaStrikeAnimationKind.scribbleOut;
  int _strikeAnimationDurationMs = kTriviaStrikeAnimationMs;

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
    final count =
        (q != null && q.optionC.trim().isEmpty && q.optionD.trim().isEmpty)
        ? 2
        : 4;
    final perm = q == null
        ? null
        : triviaShuffleOrderForTesting(_rng, optionCount: count);
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
    final displayCorrect = String.fromCharCode('A'.codeUnitAt(0) + correctIdx);
    final wrong = List<String>.generate(
      perm.length,
      (i) => String.fromCharCode('A'.codeUnitAt(0) + i),
    ).where((l) => l != displayCorrect).toList()..shuffle(_rng);

    final override = (widget.spec.config['eliminationWindowMs'] as num?)
        ?.toInt();
    final windowMs = triviaEliminationWindowMs(
      widget.slide.dwellMs,
      configOverride: override,
    );
    _strikeAnimationKind = parseTriviaStrikeAnimationKind(widget.spec.config);
    _strikeAnimationDurationMs = parseStrikeAnimationDurationMs(
      widget.spec.config,
    );
    _eliminationEndMs = triviaEliminationEndMs(
      windowMs,
      strikeAnimationMs: _strikeAnimationDurationMs,
    );
    final step = wrong.isEmpty ? windowMs : (windowMs ~/ (wrong.length + 1));
    final delays = <int>[];

    if (step < 1) {
      for (var i = 0; i < wrong.length; i++) {
        final delayMs = (windowMs * (i + 1) ~/ wrong.length).clamp(1, windowMs);
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
    for (var slot = 0; slot < perm.length; slot++) {
      if (_optionText(row, perm[slot]).length >
          kTriviaTwoColumnMaxOptionChars) {
        return false;
      }
    }
    return true;
  }

  /// Countdown bar for elimination — coral/pink track to match trivia mockups, plus strike ticks.
  Widget _buildRevealProgressBar(ThemeData theme, double s) {
    if (_eliminationEndMs <= 0) {
      return const SizedBox.shrink();
    }
    final palette = theme.extension<PaletteTertiaryLayers>();
    final coral = palette?.accent2 ?? theme.colorScheme.tertiary;
    return Padding(
      padding: EdgeInsets.only(top: 24 * s, bottom: 32 * s),
      child: Align(
        alignment: Alignment.center,
        child: FractionallySizedBox(
          widthFactor: 0.72,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = 8 * s;
              final remaining = (1.0 - _elapsedMs / _eliminationEndMs).clamp(
                0.0,
                1.0,
              );
              final borderColor = Color.alphaBlend(
                Colors.black.withValues(alpha: 0.38),
                coral,
              );
              final trackColor = Color.alphaBlend(
                Colors.white.withValues(alpha: 0.75),
                coral,
              );
              final fillColor = Color.alphaBlend(
                Colors.white.withValues(alpha: 0.45),
                coral,
              );
              final markerColor = Color.alphaBlend(
                Colors.black.withValues(alpha: 0.25),
                coral,
              );

              return Container(
                key: const ValueKey<String>('trivia_reveal_progress'),
                height: h,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4 * s),
                  border: Border.all(color: borderColor, width: 1 * s),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: trackColor,
                            borderRadius: BorderRadius.circular(3 * s),
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
                                  borderRadius: BorderRadius.circular(3 * s),
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
    required bool useTwoColumns,
    required double uniformRowHeight,
    required double uniformInnerRowWidth,
  }) {
    final displayLetter = String.fromCharCode('A'.codeUnitAt(0) + slot);
    final sourceLetter = perm[slot];
    final struck = _struckWrong.contains(displayLetter);
    final fadeStrikeOnly =
        struck && _strikeAnimationKind == TriviaStrikeAnimationKind.fadeOut;
    final useStruckPalette = fadeStrikeOnly;
    final cs = theme.colorScheme;
    final palette = theme.extension<PaletteTertiaryLayers>();
    final accentColors = [
      palette?.accent1 ?? cs.secondary,
      palette?.accent2 ?? cs.tertiary,
      palette?.accent3 ?? cs.primary,
      palette?.accent4 ?? cs.outline,
    ];
    final accentColor = accentColors[slot % accentColors.length];
    final text = _optionText(row, sourceLetter);

    final leftStripe = Color.alphaBlend(
      Colors.black.withValues(alpha: useStruckPalette ? 0.4 : 0.22),
      accentColor,
    );

    final questionTextStyle = theme.textTheme.headlineSmall;
    final optionStyle = questionTextStyle?.copyWith(
      fontWeight: FontWeight.w600,
    );

    final dividerColor = Color.alphaBlend(
      Colors.black.withValues(alpha: 0.22),
      accentColor,
    );

    final tileInset = EdgeInsets.symmetric(vertical: 5 * s, horizontal: 6 * s);
    final tileBorderRadius = BorderRadius.horizontal(
      right: Radius.circular(5 * s),
    );
    final tileClipRadius = BorderRadius.horizontal(
      right: Radius.circular(4 * s),
    );

    final optionCard = Padding(
      padding: tileInset,
      child: Container(
        decoration: BoxDecoration(borderRadius: tileBorderRadius),
        clipBehavior: Clip.antiAlias,
        child: ClipRRect(
          borderRadius: tileClipRadius,
          child: SizedBox(
            height: uniformRowHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: uniformRowHeight,
                  height: uniformRowHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: leftStripe,
                      border: Border(
                        right: BorderSide(color: dividerColor, width: 1),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        displayLetter,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                          color: _readableOnStripe(leftStripe),
                        ),
                        textHeightBehavior: const TextHeightBehavior(
                          applyHeightToFirstAscent: false,
                          applyHeightToLastDescent: false,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: max(1.0, uniformInnerRowWidth - uniformRowHeight),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: 20 * s,
                        right: 20 * s,
                        top: 12 * s,
                        bottom: 12 * s,
                      ),
                      child: Text(
                        text,
                        style: optionStyle,
                        softWrap: true,
                        textAlign: TextAlign.start,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final bottomPad = EdgeInsets.only(bottom: useTwoColumns ? 0 : 22 * s);

    if (struck) {
      final strikeStyleSeed = Object.hash(
        displayLetter.codeUnitAt(0),
        slot,
        row.id.hashCode,
      );

      return Padding(
        padding: bottomPad,
        child: TweenAnimationBuilder<double>(
          key: ValueKey<String>(
            'trivia_strike_${displayLetter}_${_strikeAnimationKind.name}_'
            '$_strikeAnimationDurationMs',
          ),
          duration: Duration(milliseconds: _strikeAnimationDurationMs),
          tween: Tween(begin: 0, end: 1),
          curve: [
            Curves.easeOutCubic,
            Curves.easeOutQuad,
            Curves.easeInOutCubic,
            Curves.decelerate,
          ][strikeStyleSeed.abs() % 4],
          builder: (context, t, _) {
            if (_strikeAnimationKind == TriviaStrikeAnimationKind.fadeOut) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Opacity(
                    opacity: (1.0 - 0.52 * t).clamp(0.0, 1.0),
                    child: optionCard,
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: tileInset,
                      child: ClipRRect(
                        borderRadius: tileClipRadius,
                        child: ColoredBox(
                          color: Colors.black.withValues(alpha: 0.12 * t),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }
            final strikeInk = Color.alphaBlend(
              Colors.white.withValues(alpha: 0.12 + 0.1 * t),
              accentColor,
            ).withValues(alpha: (0.82 + 0.16 * t).clamp(0.0, 1.0));
            return Stack(
              clipBehavior: Clip.none,
              children: [
                optionCard,
                if (_strikeAnimationKind != TriviaStrikeAnimationKind.strikeOutX)
                  Positioned.fill(
                    child: Padding(
                      padding: tileInset,
                      child: ClipRRect(
                        borderRadius: tileClipRadius,
                        child: CustomPaint(
                          key: ValueKey<String>(
                            'trivia_strike_cross_$displayLetter',
                          ),
                          painter: TriviaStrikeOverlayPainter(
                            kind: _strikeAnimationKind,
                            progress: t,
                            color: strikeInk,
                            strokeWidth: (3.5 * s).clamp(2.0, 8.0),
                            styleSeed: strikeStyleSeed,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_strikeAnimationKind == TriviaStrikeAnimationKind.strikeOutX)
                  Positioned.fill(
                    child: Padding(
                      padding: tileInset,
                      child: ClipRRect(
                        borderRadius: tileClipRadius,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: EdgeInsets.only(right: 4 * s),
                            child: Opacity(
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
                                    color: strikeInk,
                                    size: 24 * s,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      );
    }

    return Padding(padding: bottomPad, child: optionCard);
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
    final optionCount = row.optionC.trim().isEmpty && row.optionD.trim().isEmpty
        ? 2
        : 4;
    final perm = (_displaySlotToSource ?? const <String>[])
        .take(optionCount)
        .toList();
    if (perm.length != optionCount) {
      return const SizedBox.shrink();
    }
    final useTwoColumns =
        optionCount == 4 && _optionsShortForTwoColumns(row, perm);

    final paddedAnswers = Padding(
      padding: EdgeInsets.symmetric(vertical: 24 * s, horizontal: 24 * s),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final texts = List.generate(
            optionCount,
            (i) => _optionText(row, perm[i]),
          );
          final maxCellOuterW = (optionCount == 2 || useTwoColumns)
              ? (w - 22 * s) / 2
              : w;
          final maxInner = max(0.0, maxCellOuterW - 12 * s);
          final optionStyleMeasure = theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          );
          final geom = triviaUniformOptionGeometryForTesting(
            maxInnerRowWidth: maxInner > 0 ? maxInner : 1.0,
            optionTexts: texts,
            optionStyle: optionStyleMeasure,
            textScaler: MediaQuery.textScalerOf(context),
            s: s,
          );
          final uniformInnerRowWidth = geom.innerRowWidth;
          final uniformRowHeight = geom.rowHeight;
          final tileOuterW = uniformInnerRowWidth + 12 * s;

          final answersSection = Align(
            alignment: Alignment.topCenter,
            child: optionCount == 2
                ? KeyedSubtree(
                    key: const ValueKey<String>('trivia_answers_true_false'),
                    child: SizedBox(
                      width: tileOuterW * 2 + 22 * s,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: tileOuterW,
                            child: _optionTile(
                              row: row,
                              perm: perm,
                              slot: 0,
                              theme: theme,
                              s: s,
                              useTwoColumns: true,
                              uniformRowHeight: uniformRowHeight,
                              uniformInnerRowWidth: uniformInnerRowWidth,
                            ),
                          ),
                          SizedBox(width: 22 * s),
                          SizedBox(
                            width: tileOuterW,
                            child: _optionTile(
                              row: row,
                              perm: perm,
                              slot: 1,
                              theme: theme,
                              s: s,
                              useTwoColumns: true,
                              uniformRowHeight: uniformRowHeight,
                              uniformInnerRowWidth: uniformInnerRowWidth,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : useTwoColumns
                ? KeyedSubtree(
                    key: const ValueKey<String>('trivia_answers_grid'),
                    child: SizedBox(
                      width: tileOuterW * 2 + 22 * s,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: tileOuterW,
                                child: _optionTile(
                                  row: row,
                                  perm: perm,
                                  slot: 0,
                                  theme: theme,
                                  s: s,
                                  useTwoColumns: true,
                                  uniformRowHeight: uniformRowHeight,
                                  uniformInnerRowWidth: uniformInnerRowWidth,
                                ),
                              ),
                              SizedBox(width: 22 * s),
                              SizedBox(
                                width: tileOuterW,
                                child: _optionTile(
                                  row: row,
                                  perm: perm,
                                  slot: 1,
                                  theme: theme,
                                  s: s,
                                  useTwoColumns: true,
                                  uniformRowHeight: uniformRowHeight,
                                  uniformInnerRowWidth: uniformInnerRowWidth,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 22 * s),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: tileOuterW,
                                child: _optionTile(
                                  row: row,
                                  perm: perm,
                                  slot: 2,
                                  theme: theme,
                                  s: s,
                                  useTwoColumns: true,
                                  uniformRowHeight: uniformRowHeight,
                                  uniformInnerRowWidth: uniformInnerRowWidth,
                                ),
                              ),
                              SizedBox(width: 22 * s),
                              SizedBox(
                                width: tileOuterW,
                                child: _optionTile(
                                  row: row,
                                  perm: perm,
                                  slot: 3,
                                  theme: theme,
                                  s: s,
                                  useTwoColumns: true,
                                  uniformRowHeight: uniformRowHeight,
                                  uniformInnerRowWidth: uniformInnerRowWidth,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                : KeyedSubtree(
                    key: const ValueKey<String>('trivia_answers_column'),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: List.generate(optionCount, (slot) {
                        return SizedBox(
                          width: tileOuterW,
                          child: _optionTile(
                            row: row,
                            perm: perm,
                            slot: slot,
                            theme: theme,
                            s: s,
                            useTwoColumns: false,
                            uniformRowHeight: uniformRowHeight,
                            uniformInnerRowWidth: uniformInnerRowWidth,
                          ),
                        );
                      }),
                    ),
                  ),
          );

          return answersSection;
        },
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
          paddedAnswers,
        ],
      ),
    );
  }
}
