import 'dart:math';

import 'screen_layout_parse.dart' show ParsedWidgetSpec, parseScreenLayoutWidgets;

class DataKeyProgramLimit {
  const DataKeyProgramLimit({
    this.minPlacementsPerProgram = 0,
    this.maxPlacementsPerProgram,
  });

  final int minPlacementsPerProgram;
  final int? maxPlacementsPerProgram;
}

/// Row-shaped input for [ScreenProgramCurator] (from DB or tests).
class ScreenCandidate {
  const ScreenCandidate({
    required this.id,
    required this.dwellMs,
    required this.frequencyWeight,
    required this.minGapBetweenShowsMs,
    this.minPlacementsPerProgram = 0,
    this.maxPlacementsPerProgram,
    this.dataKey = '',
    required this.layoutJson,
    required this.enabled,
  });

  final String id;
  final int dwellMs;
  final int frequencyWeight;
  final int minGapBetweenShowsMs;
  final int minPlacementsPerProgram;
  final int? maxPlacementsPerProgram;
  final String dataKey;
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

  /// Keys [ParsedWidgetSpec.choiceKey] → curated content id (blob key, joke id,
  /// RSS article id, trivia question id, …) chosen for this slide.
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
    Map<String, DataKeyProgramLimit> dataKeyLimits = const {},
  }) {
    final enabled = screens.where((s) => s.enabled && s.dwellMs > 0).toList();
    if (enabled.isEmpty || programDurationMs <= 0) {
      return const [];
    }

    final window = historyWindowSlice(recentScreenIdsOldestFirst, historyDepth);

    var remaining = programDurationMs;
    final out = <ResolvedSlide>[];
    final usedCuratedIds = <String>{};
    final countByScreenId = <String, int>{};
    final countByDataKey = <String, int>{};

    while (remaining > 0) {
      final eligible =
          enabled
              .where(
                (s) => _canPlaceScreen(
                  s,
                  countByScreenId,
                  countByDataKey,
                  dataKeyLimits,
                ),
              )
              .toList();
      if (eligible.isEmpty) {
        break;
      }
      final priority = _prioritizedForMins(
        eligible: eligible,
        countByScreenId: countByScreenId,
        countByDataKey: countByDataKey,
        dataKeyLimits: dataKeyLimits,
      );
      final pick = _weightedPick(
        priority.isNotEmpty ? priority : eligible,
        window,
        random,
      );
      if (pick == null) {
        break;
      }
      final dwell = min(pick.dwellMs, remaining);
      final choices = _resolveCuratedWidgetChoices(
        pick.layoutJson,
        randomPools,
        random,
        usedCuratedIds,
      );
      out.add(
        ResolvedSlide(
          screenId: pick.id,
          dwellMs: dwell,
          layoutJson: pick.layoutJson,
          randomChoices: choices,
        ),
      );
      countByScreenId[pick.id] = (countByScreenId[pick.id] ?? 0) + 1;
      final key = pick.dataKey.trim();
      if (key.isNotEmpty) {
        countByDataKey[key] = (countByDataKey[key] ?? 0) + 1;
      }
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

  static bool _canPlaceScreen(
    ScreenCandidate s,
    Map<String, int> countByScreenId,
    Map<String, int> countByDataKey,
    Map<String, DataKeyProgramLimit> dataKeyLimits,
  ) {
    final maxByScreen = _normalizedScreenMax(s);
    if (maxByScreen != null && (countByScreenId[s.id] ?? 0) >= maxByScreen) {
      return false;
    }
    final key = s.dataKey.trim();
    if (key.isEmpty) {
      return true;
    }
    final keyLimit = dataKeyLimits[key];
    final maxByKey = _normalizedMax(keyLimit?.maxPlacementsPerProgram);
    if (maxByKey != null && (countByDataKey[key] ?? 0) >= maxByKey) {
      return false;
    }
    return true;
  }

  static List<ScreenCandidate> _prioritizedForMins({
    required List<ScreenCandidate> eligible,
    required Map<String, int> countByScreenId,
    required Map<String, int> countByDataKey,
    required Map<String, DataKeyProgramLimit> dataKeyLimits,
  }) {
    final out = <ScreenCandidate>[];
    for (final s in eligible) {
      final minByScreen = _normalizedMin(s.minPlacementsPerProgram);
      if ((countByScreenId[s.id] ?? 0) < minByScreen) {
        out.add(s);
        continue;
      }
      final key = s.dataKey.trim();
      if (key.isEmpty) {
        continue;
      }
      final minByKey = _normalizedMin(dataKeyLimits[key]?.minPlacementsPerProgram);
      if ((countByDataKey[key] ?? 0) < minByKey) {
        out.add(s);
      }
    }
    return out;
  }

  static int _normalizedMin(int? value) {
    if (value == null || value < 0) {
      return 0;
    }
    return value;
  }

  static int? _normalizedMax(int? value) {
    if (value == null || value < 0) {
      return null;
    }
    return value;
  }

  static int? _normalizedScreenMax(ScreenCandidate s) {
    final min = _normalizedMin(s.minPlacementsPerProgram);
    final max = _normalizedMax(s.maxPlacementsPerProgram);
    if (max == null) {
      return null;
    }
    return max < min ? min : max;
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

  /// Picks one unused id from [pool] when possible; skips if pool missing or
  /// all ids already used (callers/widgets may fall back).
  static String? _pickUnusedFromPool(
    List<String>? pool,
    Random random,
    Set<String> used,
  ) {
    if (pool == null || pool.isEmpty) {
      return null;
    }
    final available = pool.where((id) => !used.contains(id)).toList();
    if (available.isEmpty) {
      return null;
    }
    final choice = available[random.nextInt(available.length)];
    used.add(choice);
    return choice;
  }

  static String? _poolNameForWidget(ParsedWidgetSpec w) {
    switch (w.type) {
      case 'photo_random':
        return w.config['pool'] as String?;
      case 'joke':
        final c = w.config['categoryId'] as String?;
        return (c != null && c.isNotEmpty) ? 'joke:$c' : 'joke';
      case 'rss_article':
      case 'rss_article_columns':
        final f = w.config['feedId'] as String?;
        return (f != null && f.isNotEmpty) ? 'rss:$f' : 'rss';
      case 'trivia':
        final c = w.config['categoryId'] as String?;
        return (c != null && c.isNotEmpty) ? 'trivia:$c' : 'trivia';
      default:
        return null;
    }
  }

  static int _rssArticleColumnCount(Map<String, dynamic> config) {
    final v = config['columnCount'];
    if (v is int) {
      return v.clamp(1, 6);
    }
    if (v is double) {
      return v.round().clamp(1, 6);
    }
    return 3;
  }

  static Map<String, String> _resolveCuratedWidgetChoices(
    String layoutJson,
    Map<String, List<String>> randomPools,
    Random random,
    Set<String> usedCuratedIds,
  ) {
    final specs = parseScreenLayoutWidgets(layoutJson);
    final out = <String, String>{};
    for (final w in specs) {
      if (w.type == 'rss_article_columns') {
        final poolName = _poolNameForWidget(w);
        if (poolName == null || poolName.isEmpty) {
          continue;
        }
        final n = _rssArticleColumnCount(w.config);
        for (var i = 0; i < n; i++) {
          final choice = _pickUnusedFromPool(
            randomPools[poolName],
            random,
            usedCuratedIds,
          );
          if (choice != null) {
            out['${w.choiceKey}_$i'] = choice;
          }
        }
        continue;
      }
      final poolName = _poolNameForWidget(w);
      if (poolName == null || poolName.isEmpty) {
        continue;
      }
      final choice = _pickUnusedFromPool(
        randomPools[poolName],
        random,
        usedCuratedIds,
      );
      if (choice != null) {
        out[w.choiceKey] = choice;
      }
    }
    return out;
  }
}
