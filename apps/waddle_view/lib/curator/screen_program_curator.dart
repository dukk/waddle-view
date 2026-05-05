import 'dart:math';

import 'screen_layout_parse.dart';

/// Row-shaped input for [ScreenProgramCurator] (from DB or tests).
class ScreenCandidate {
  const ScreenCandidate({
    required this.id,
    required this.dwellMs,
    required this.frequencyWeight,
    required this.minGapBetweenShowsMs,
    required this.layoutJson,
    required this.enabled,
  });

  final String id;
  final int dwellMs;
  final int frequencyWeight;
  final int minGapBetweenShowsMs;
  final String layoutJson;
  final bool enabled;
}

/// One slide in a curated program (in order).
class ResolvedSlide {
  const ResolvedSlide({
    required this.screenId,
    required this.dwellMs,
    required this.layoutJson,
    this.randomChoices = const {},
  });

  final String screenId;
  final int dwellMs;
  final String layoutJson;

  /// Keys [ParsedWidgetSpec.choiceKey] → chosen asset id (or token).
  final Map<String, String> randomChoices;
}

/// Builds an ordered list of slides that fits [programDurationMs], biased away
/// from screen ids that appear often in [recentScreenIdsOldestFirst].
class ScreenProgramCurator {
  ScreenProgramCurator._();

  /// [recentScreenIdsOldestFirst]: full trace of shown screens; only the last
  /// [historyDepth] ids influence weighting.
  static List<ResolvedSlide> buildProgram({
    required List<ScreenCandidate> screens,
    required int programDurationMs,
    required List<String> recentScreenIdsOldestFirst,
    required int historyDepth,
    required Random random,
    Map<String, List<String>> randomPools = const {},
  }) {
    final enabled = screens.where((s) => s.enabled && s.dwellMs > 0).toList();
    if (enabled.isEmpty || programDurationMs <= 0) {
      return const [];
    }

    final window = historyWindowSlice(recentScreenIdsOldestFirst, historyDepth);

    var remaining = programDurationMs;
    final out = <ResolvedSlide>[];
    final usedRandomAssets = <String>{};

    while (remaining > 0) {
      final pick = _weightedPick(enabled, window, random);
      if (pick == null) {
        break;
      }
      final dwell = min(pick.dwellMs, remaining);
      final choices = _resolveRandomWidgets(
        pick.layoutJson,
        randomPools,
        random,
        usedRandomAssets,
      );
      out.add(
        ResolvedSlide(
          screenId: pick.id,
          dwellMs: dwell,
          layoutJson: pick.layoutJson,
          randomChoices: choices,
        ),
      );
      remaining -= dwell;
    }

    return out;
  }

  /// Last [depth] ids from [full] (oldest → newest), used for weighting and logs.
  static List<String> historyWindowSlice(List<String> full, int depth) {
    if (depth <= 0 || full.isEmpty) {
      return const [];
    }
    if (full.length <= depth) {
      return List<String>.from(full);
    }
    return full.sublist(full.length - depth);
  }

  /// Debug-only friendly lines (caller should gate with [kDebugMode]).
  static List<String> curatedProgramDebugLogLines({
    required List<ResolvedSlide> program,
    required int programDurationMs,
    required int historyDepth,
    required List<String> recentScreenIdsOldestFirst,
  }) {
    final window =
        historyWindowSlice(recentScreenIdsOldestFirst, historyDepth);
    if (program.isEmpty) {
      return [
        'curated slides: 0 (programDurationMs=$programDurationMs, '
            'historyDepth=$historyDepth, '
            'weightWindow(oldest→newest)=$window)',
      ];
    }
    final totalDwellMs = program.fold<int>(0, (a, s) => a + s.dwellMs);
    final slideParts = <String>[];
    for (var i = 0; i < program.length; i++) {
      final s = program[i];
      final choices = s.randomChoices.entries.map((e) => '${e.key}→${e.value}');
      final choiceSuffix =
          s.randomChoices.isEmpty ? '' : ' random={${choices.join(', ')}}';
      slideParts.add('[$i] ${s.screenId} ${s.dwellMs}ms$choiceSuffix');
    }
    final lines = <String>[
      'curated slides: ${program.length} (totalDwellMs=$totalDwellMs, '
          'budgetMs=$programDurationMs, historyDepth=$historyDepth, '
          'weightWindow(oldest→newest)=$window)',
      slideParts.join('; '),
    ];
    for (var i = 1; i < program.length; i++) {
      if (program[i].screenId == program[i - 1].screenId) {
        lines.add(
          'consecutive duplicate screenId="${program[i].screenId}" '
          'at slide indices ${i - 1}→$i',
        );
      }
    }
    return lines;
  }

  static double _effectiveWeight(ScreenCandidate c, List<String> historyWindow) {
    final count = historyWindow.where((id) => id == c.id).length;
    return c.frequencyWeight / (1.0 + count);
  }

  static ScreenCandidate? _weightedPick(
    List<ScreenCandidate> enabled,
    List<String> historyWindow,
    Random random,
  ) {
    final weights = enabled
        .map((c) => _effectiveWeight(c, historyWindow))
        .toList();
    final total = weights.fold<double>(0, (a, b) => a + b);
    if (total <= 0) {
      return null;
    }
    var t = random.nextDouble() * total;
    for (var i = 0; i < enabled.length; i++) {
      t -= weights[i];
      if (t <= 0) {
        return enabled[i];
      }
    }
    return enabled.last;
  }

  static Map<String, String> _resolveRandomWidgets(
    String layoutJson,
    Map<String, List<String>> randomPools,
    Random random,
    Set<String> usedRandomAssets,
  ) {
    final specs = parseScreenLayoutWidgets(layoutJson);
    final out = <String, String>{};
    for (final w in specs) {
      if (w.type != 'photo_random') {
        continue;
      }
      final poolName = w.config['pool'] as String?;
      if (poolName == null) {
        continue;
      }
      final pool = randomPools[poolName];
      if (pool == null || pool.isEmpty) {
        continue;
      }
      final available = pool.where((id) => !usedRandomAssets.contains(id)).toList();
      if (available.isEmpty) {
        continue;
      }
      final choice = available[random.nextInt(available.length)];
      usedRandomAssets.add(choice);
      out[w.choiceKey] = choice;
    }
    return out;
  }
}
