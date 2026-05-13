import 'dart:math';

import 'curator_content_pools.dart' show PhotoCuratorMetric, RssArticleMetric;
import 'photo_collage_curation.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart'
    show ParsedWidgetSpec, parseScreenLayoutWidgets;

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

/// Curator tuning: penalize summary overflow much more than under-use.
const double _kPenaltyOverCapacity = 10.0;
const double _kPenaltyUnderCapacity = 1.0;

const int _kRssCategoryPoolPrefixLength = 13; // 'rss_category:'.length

/// Builds an ordered list of slides that fits [programDurationMs], biased away
/// from screen ids that appear often in [recentScreenIdsOldestFirst].
class ScreenProgramCurator {
  ScreenProgramCurator._();

  /// [ResolvedSlide.randomChoices] key for the unified RSS content category on this slide.
  static const rssScreenCategoryChoiceKey = 'rss_screen_category_id';

  static bool _countsTowardCuratedIdDedup(String choiceKey) {
    if (choiceKey == rssScreenCategoryChoiceKey) {
      return false;
    }
    if (choiceKey.endsWith('_imageMode')) {
      return false;
    }
    return true;
  }

  static void _addResolvedChoicesToUsedCuratedIds(
    Map<String, String> choices,
    Set<String> usedCuratedIds,
  ) {
    for (final e in choices.entries) {
      if (_countsTowardCuratedIdDedup(e.key)) {
        usedCuratedIds.add(e.value);
      }
    }
  }

  /// [recentScreenIdsOldestFirst]: full trace of shown screens; only the last
  /// [historyDepth] ids influence weighting.
  ///
  /// When [rssArticleMetrics] is non-empty and [layoutHasRssNews] for a screen,
  /// joint best-fit placement prefers screens whose per-slot summary capacity
  /// matches article lengths. [requirePhotoForRssScreens] restricts pools to
  /// rows with images unless min-placement fallback forces photo-less articles
  /// (`*_imageMode` = `icon` in [ResolvedSlide.randomChoices]).
  static List<ResolvedSlide> buildProgram({
    required List<ScreenCandidate> screens,
    required int programDurationMs,
    required List<String> recentScreenIdsOldestFirst,
    required int historyDepth,
    required Random random,
    Map<String, List<String>> randomPools = const {},
    Map<String, DataKeyProgramLimit> dataKeyLimits = const {},
    Map<String, RssArticleMetric> rssArticleMetrics = const {},
    Map<String, PhotoCuratorMetric> photoMetrics = const {},
    bool requirePhotoForRssScreens = true,
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

      List<ScreenCandidate> feasibleEligible;
      final Map<String, _NewsAssignment> rssAssignmentByScreenId = {};

      if (rssArticleMetrics.isNotEmpty) {
        for (final s in eligible) {
          if (!_layoutHasRssNews(s.layoutJson)) {
            continue;
          }
          final a = _resolveNewsAssignment(
            screen: s,
            randomPools: randomPools,
            usedCuratedIds: usedCuratedIds,
            rssArticleMetrics: rssArticleMetrics,
            requirePhotoForRssScreens: requirePhotoForRssScreens,
            needsMinFallback: _needsMinPlacementFallback(
              s,
              countByScreenId,
              countByDataKey,
              dataKeyLimits,
            ),
            random: random,
          );
          if (a != null) {
            rssAssignmentByScreenId[s.id] = a;
          }
        }
        feasibleEligible =
            eligible.where((s) {
              if (!_layoutHasRssNews(s.layoutJson)) {
                return true;
              }
              return rssAssignmentByScreenId.containsKey(s.id);
            }).toList();
      } else {
        feasibleEligible =
            eligible.where((s) {
              if (!_layoutHasRssNews(s.layoutJson)) {
                return true;
              }
              return _legacyNewsFeasible(
                layoutJson: s.layoutJson,
                randomPools: randomPools,
                usedCuratedIds: usedCuratedIds,
              );
            }).toList();
      }

      if (feasibleEligible.isEmpty) {
        break;
      }

      final priority = _prioritizedForMins(
        eligible: feasibleEligible,
        countByScreenId: countByScreenId,
        countByDataKey: countByDataKey,
        dataKeyLimits: dataKeyLimits,
      );
      final activePool = priority.isNotEmpty ? priority : feasibleEligible;

      ScreenCandidate? pick;
      Map<String, String>? resolvedChoices;

      if (rssArticleMetrics.isNotEmpty &&
          activePool.any((s) => _layoutHasRssNews(s.layoutJson))) {
        final options = <_PickOption>[];
        for (final s in activePool) {
          if (_layoutHasRssNews(s.layoutJson)) {
            continue;
          }
          options.add(_PickOptionNonNews(s));
        }
        for (final s in activePool) {
          if (!_layoutHasRssNews(s.layoutJson)) {
            continue;
          }
          final a = rssAssignmentByScreenId[s.id];
          if (a != null) {
            options.add(_PickOptionNewsJoint(s, a));
          }
        }
        if (options.isEmpty) {
          break;
        }

        final selected = _weightedPickOption(options, window, random);
        if (selected == null) {
          break;
        }
        if (selected is _PickOptionNonNews) {
          pick = selected.screen;
          resolvedChoices = _resolveCuratedWidgetChoices(
            selected.screen.layoutJson,
            randomPools,
            random,
            usedCuratedIds,
            photoMetrics: photoMetrics,
          );
        } else if (selected is _PickOptionNewsJoint) {
          pick = selected.screen;
          resolvedChoices = Map<String, String>.from(selected.assignment.choices);
          _addResolvedChoicesToUsedCuratedIds(
            selected.assignment.choices,
            usedCuratedIds,
          );
        }
      } else {
        final pickScreen = _weightedPick(activePool, window, random);
        if (pickScreen == null) {
          break;
        }
        pick = pickScreen;
        if (_layoutHasRssNews(pick.layoutJson) && rssArticleMetrics.isEmpty) {
          resolvedChoices = _resolveCuratedWidgetChoices(
            pick.layoutJson,
            randomPools,
            random,
            usedCuratedIds,
            photoMetrics: photoMetrics,
          );
        } else if (_layoutHasRssNews(pick.layoutJson)) {
          final a = rssArticleMetrics.isNotEmpty
              ? rssAssignmentByScreenId[pick.id]
              : _resolveNewsAssignment(
                  screen: pick,
                  randomPools: randomPools,
                  usedCuratedIds: usedCuratedIds,
                  rssArticleMetrics: rssArticleMetrics,
                  requirePhotoForRssScreens: requirePhotoForRssScreens,
                  needsMinFallback: _needsMinPlacementFallback(
                    pick,
                    countByScreenId,
                    countByDataKey,
                    dataKeyLimits,
                  ),
                  random: random,
                );
          if (a == null) {
            break;
          }
          resolvedChoices = Map<String, String>.from(a.choices);
          _addResolvedChoicesToUsedCuratedIds(a.choices, usedCuratedIds);
        } else {
          resolvedChoices = _resolveCuratedWidgetChoices(
            pick.layoutJson,
            randomPools,
            random,
            usedCuratedIds,
            photoMetrics: photoMetrics,
          );
        }
      }

      if (pick == null || resolvedChoices == null) {
        break;
      }

      final dwell = min(pick.dwellMs, remaining);
      out.add(
        ResolvedSlide(
          screenId: pick.id,
          dwellMs: dwell,
          layoutJson: pick.layoutJson,
          randomChoices: resolvedChoices,
        ),
      );
      countByScreenId[pick.id] = (countByScreenId[pick.id] ?? 0) + 1;
      final dk = pick.dataKey.trim();
      if (dk.isNotEmpty) {
        countByDataKey[dk] = (countByDataKey[dk] ?? 0) + 1;
      }
      remaining -= dwell;
    }

    return out;
  }

  static bool _layoutHasRssNews(String layoutJson) {
    return parseScreenLayoutWidgets(layoutJson).any(
      (w) => w.rssSummarySlotCapacities.isNotEmpty,
    );
  }

  static bool _needsMinPlacementFallback(
    ScreenCandidate s,
    Map<String, int> countByScreenId,
    Map<String, int> countByDataKey,
    Map<String, DataKeyProgramLimit> dataKeyLimits,
  ) {
    final minByScreen = _normalizedMin(s.minPlacementsPerProgram);
    if ((countByScreenId[s.id] ?? 0) < minByScreen) {
      return true;
    }
    final dk = s.dataKey.trim();
    if (dk.isEmpty) {
      return false;
    }
    final minByKey = _normalizedMin(dataKeyLimits[dk]?.minPlacementsPerProgram);
    return (countByDataKey[dk] ?? 0) < minByKey;
  }

  static bool _legacyNewsFeasible({
    required String layoutJson,
    required Map<String, List<String>> randomPools,
    required Set<String> usedCuratedIds,
  }) {
    final used = {...usedCuratedIds};
    final choices = _resolveCuratedWidgetChoices(
      layoutJson,
      randomPools,
      Random(0),
      used,
      photoMetrics: const {},
    );
    final specs = parseScreenLayoutWidgets(layoutJson);
    for (final w in specs) {
      if (w.rssSummarySlotCapacities.isEmpty) {
        continue;
      }
      if (w.type == 'rss_article_columns') {
        final n = w.rssSummarySlotCapacities.length;
        for (var i = 0; i < n; i++) {
          if ((choices['${w.choiceKey}_$i'] ?? '').isEmpty) {
            return false;
          }
        }
      } else if (w.type == 'rss_article_stack') {
        for (var i = 0; i < 2; i++) {
          if ((choices['${w.choiceKey}_$i'] ?? '').isEmpty) {
            return false;
          }
        }
      } else {
        if ((choices[w.choiceKey] ?? '').isEmpty) {
          return false;
        }
      }
    }
    return true;
  }

  static double _slotCost(int summaryLen, int capacity) {
    final over = max(0, summaryLen - capacity);
    final under = max(0, capacity - summaryLen);
    return _kPenaltyOverCapacity * over + _kPenaltyUnderCapacity * under;
  }

  static _NewsAssignment? _resolveNewsAssignment({
    required ScreenCandidate screen,
    required Map<String, List<String>> randomPools,
    required Set<String> usedCuratedIds,
    required Map<String, RssArticleMetric> rssArticleMetrics,
    required bool requirePhotoForRssScreens,
    required bool needsMinFallback,
    required Random random,
  }) {
    final specs =
        parseScreenLayoutWidgets(
          screen.layoutJson,
        ).where((w) => w.rssSummarySlotCapacities.isNotEmpty).toList();
    if (specs.isEmpty) {
      return null;
    }

    final requirePhoto =
        requirePhotoForRssScreens && !needsMinFallback;
    final reservedIds = {...usedCuratedIds};
    final totalSlots = specs.fold<int>(
      0,
      (a, w) => a + w.rssSummarySlotCapacities.length,
    );

    String? forcedCategory;
    for (final w in specs) {
      final poolName = _poolNameForWidget(w);
      if (poolName == null || poolName.isEmpty) {
        return null;
      }
      if (poolName.startsWith('rss_category:')) {
        final c = poolName.substring(_kRssCategoryPoolPrefixLength);
        if (forcedCategory != null && forcedCategory != c) {
          return null;
        }
        forcedCategory = c;
      } else if (poolName.startsWith('rss:') && poolName.length > 4) {
        final pool = randomPools[poolName] ?? [];
        if (pool.isEmpty) {
          return null;
        }
        final c =
            rssArticleMetrics[pool.first]?.categoryId ?? 'general';
        if (forcedCategory != null && forcedCategory != c) {
          return null;
        }
        forcedCategory = c;
      }
    }

    final hasGlobalRss =
        specs.any((w) => _poolNameForWidget(w) == 'rss');
    String? screenCategory = forcedCategory;
    if (hasGlobalRss) {
      final rssPool = randomPools['rss'] ?? [];
      if (screenCategory != null) {
        if (!_rssPoolHasEnoughForCategory(
          rssPool: rssPool,
          categoryId: screenCategory,
          reservedIds: reservedIds,
          rssArticleMetrics: rssArticleMetrics,
          requirePhoto: requirePhoto,
          need: totalSlots,
        )) {
          return null;
        }
      } else {
        screenCategory = _pickGlobalRssCategory(
          rssPool: rssPool,
          totalSlots: totalSlots,
          reservedIds: reservedIds,
          rssArticleMetrics: rssArticleMetrics,
          requirePhoto: requirePhoto,
          random: random,
        );
        if (screenCategory == null) {
          return null;
        }
      }
    } else {
      screenCategory ??= forcedCategory;
    }

    final choices = <String, String>{};
    if (screenCategory != null) {
      choices[rssScreenCategoryChoiceKey] = screenCategory;
    }

    double totalCost = 0;

    for (final w in specs) {
      final poolName = _poolNameForWidget(w);
      if (poolName == null || poolName.isEmpty) {
        return null;
      }
      var basePool = List<String>.from(randomPools[poolName] ?? []);
      if (poolName == 'rss' && screenCategory != null) {
        basePool =
            basePool
                .where(
                  (id) =>
                      (rssArticleMetrics[id]?.categoryId ?? 'general') ==
                      screenCategory,
                )
                .toList();
      }
      final slots = w.rssSummarySlotCapacities;
      final n = slots.length;

      List<String> availablePhotoOk() {
        return basePool
            .where(
              (id) =>
                  !reservedIds.contains(id) &&
                  (rssArticleMetrics[id]?.hasImage ?? false),
            )
            .toList();
      }

      List<String> availableAny() {
        return basePool.where((id) => !reservedIds.contains(id)).toList();
      }

      late List<String> pool;
      if (!requirePhotoForRssScreens || needsMinFallback) {
        pool = availableAny();
      } else {
        pool = availablePhotoOk();
      }
      if (pool.length < n) {
        return null;
      }

      final picked = _bestArticleAssignment(
        slots,
        pool,
        rssArticleMetrics,
      );
      if (picked == null) {
        return null;
      }

      for (var i = 0; i < n; i++) {
        final id = picked[i];
        reservedIds.add(id);
        final cap = slots[i];
        final len = rssArticleMetrics[id]?.summaryLength ?? 0;
        totalCost += _slotCost(len, cap);

        if (w.type == 'rss_article_columns' || w.type == 'rss_article_stack') {
          choices['${w.choiceKey}_$i'] = id;
        } else {
          choices[w.choiceKey] = id;
        }

        final hasImage = rssArticleMetrics[id]?.hasImage ?? false;
        if (!hasImage) {
          final modeKey =
              (w.type == 'rss_article_columns' || w.type == 'rss_article_stack')
              ? '${w.choiceKey}_${i}_imageMode'
              : '${w.choiceKey}_imageMode';
          choices[modeKey] = 'icon';
        }
      }
    }

    if (!_rssAssignmentCategoriesConsistent(
      specs: specs,
      choices: choices,
      rssArticleMetrics: rssArticleMetrics,
    )) {
      return null;
    }

    return _NewsAssignment(screen: screen, choices: choices, cost: totalCost);
  }

  static bool _rssPoolHasEnoughForCategory({
    required List<String> rssPool,
    required String categoryId,
    required Set<String> reservedIds,
    required Map<String, RssArticleMetric> rssArticleMetrics,
    required bool requirePhoto,
    required int need,
  }) {
    var n = 0;
    for (final id in rssPool) {
      if (reservedIds.contains(id)) {
        continue;
      }
      if ((rssArticleMetrics[id]?.categoryId ?? 'general') != categoryId) {
        continue;
      }
      if (requirePhoto && !(rssArticleMetrics[id]?.hasImage ?? false)) {
        continue;
      }
      n++;
      if (n >= need) {
        return true;
      }
    }
    return false;
  }

  static String? _pickGlobalRssCategory({
    required List<String> rssPool,
    required int totalSlots,
    required Set<String> reservedIds,
    required Map<String, RssArticleMetric> rssArticleMetrics,
    required bool requirePhoto,
    required Random random,
  }) {
    final counts = <String, int>{};
    for (final id in rssPool) {
      if (reservedIds.contains(id)) {
        continue;
      }
      if (requirePhoto && !(rssArticleMetrics[id]?.hasImage ?? false)) {
        continue;
      }
      final c = rssArticleMetrics[id]?.categoryId ?? 'general';
      counts[c] = (counts[c] ?? 0) + 1;
    }
    final feasible =
        counts.entries
            .where((e) => e.value >= totalSlots)
            .map((e) => e.key)
            .toList();
    if (feasible.isEmpty) {
      return null;
    }
    return feasible[random.nextInt(feasible.length)];
  }

  static bool _rssAssignmentCategoriesConsistent({
    required List<ParsedWidgetSpec> specs,
    required Map<String, String> choices,
    required Map<String, RssArticleMetric> rssArticleMetrics,
  }) {
    String? seen;
    for (final w in specs) {
      final n = w.rssSummarySlotCapacities.length;
      for (var i = 0; i < n; i++) {
        final key =
            (w.type == 'rss_article_columns' || w.type == 'rss_article_stack')
            ? '${w.choiceKey}_$i'
            : w.choiceKey;
        final id = choices[key];
        if (id == null || id.isEmpty) {
          return false;
        }
        final c = rssArticleMetrics[id]?.categoryId ?? 'general';
        seen ??= c;
        if (seen != c) {
          return false;
        }
      }
    }
    return true;
  }

  static List<String>? _bestArticleAssignment(
    List<int> slots,
    List<String> available,
    Map<String, RssArticleMetric> rssArticleMetrics,
  ) {
    final n = slots.length;
    if (available.length < n) {
      return null;
    }
    if (n == 0) {
      return [];
    }

    if (available.length <= 15 && n <= 4) {
      return _bestAssignmentBruteForce(slots, available, rssArticleMetrics);
    }
    return _bestAssignmentGreedy(slots, available, rssArticleMetrics);
  }

  static List<String>? _bestAssignmentBruteForce(
    List<int> slots,
    List<String> available,
    Map<String, RssArticleMetric> rssArticleMetrics,
  ) {
    final n = slots.length;
    List<String>? bestPick;
    var bestCost = double.infinity;

    void enumerate(List<String> prefix, List<String> remaining) {
      if (prefix.length == n) {
        var c = 0.0;
        for (var i = 0; i < n; i++) {
          final len = rssArticleMetrics[prefix[i]]?.summaryLength ?? 0;
          c += _slotCost(len, slots[i]);
        }
        if (c < bestCost) {
          bestCost = c;
          bestPick = List<String>.from(prefix);
        }
        return;
      }
      for (var i = 0; i < remaining.length; i++) {
        final id = remaining[i];
        final rest = List<String>.from(remaining)..removeAt(i);
        enumerate([...prefix, id], rest);
      }
    }

    enumerate([], List<String>.from(available));
    return bestPick;
  }

  static List<String>? _bestAssignmentGreedy(
    List<int> slots,
    List<String> available,
    Map<String, RssArticleMetric> rssArticleMetrics,
  ) {
    final n = slots.length;
    final unused = available.toSet();
    final out = <String>[];
    for (var si = 0; si < n; si++) {
      final cap = slots[si];
      String? bestId;
      var bestC = double.infinity;
      for (final id in unused) {
        final len = rssArticleMetrics[id]?.summaryLength ?? 0;
        final c = _slotCost(len, cap);
        if (c < bestC) {
          bestC = c;
          bestId = id;
        }
      }
      if (bestId == null) {
        return null;
      }
      out.add(bestId);
      unused.remove(bestId);
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

  static _PickOption? _weightedPickOption(
    List<_PickOption> options,
    List<String> historyWindow,
    Random random,
  ) {
    if (options.isEmpty) {
      return null;
    }
    var minNewsCost = double.infinity;
    for (final o in options) {
      if (o is _PickOptionNewsJoint) {
        final c = o.assignment.cost;
        if (c < minNewsCost) {
          minNewsCost = c;
        }
      }
    }
    final weights = options.map((o) {
      var w = _effectiveWeight(o.screen, historyWindow);
      if (o is _PickOptionNewsJoint && minNewsCost.isFinite) {
        final excess = max(0.0, o.assignment.cost - minNewsCost);
        w /= 1.0 + excess;
      }
      return w;
    }).toList();
    final total = weights.fold<double>(0, (a, b) => a + b);
    if (total <= 0) {
      return null;
    }
    var t = random.nextDouble() * total;
    for (var i = 0; i < options.length; i++) {
      t -= weights[i];
      if (t <= 0) {
        return options[i];
      }
    }
    return options.last;
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
      case 'rss_article_stack':
        final f = w.config['feedId'] as String?;
        if (f != null && f.isNotEmpty) {
          return 'rss:$f';
        }
        final c = w.config['categoryId'] as String?;
        if (c != null && c.isNotEmpty) {
          return 'rss_category:$c';
        }
        return 'rss';
      case 'trivia':
        final c = w.config['categoryId'] as String?;
        return (c != null && c.isNotEmpty) ? 'trivia:$c' : 'trivia';
      case 'pexels_photo':
        final c = w.config['categoryId'] as String?;
        return (c != null && c.isNotEmpty) ? 'pexels_photo:$c' : 'pexels_photo';
      case 'pexels_photo_collage':
        final c2 = w.config['categoryId'] as String?;
        return (c2 != null && c2.isNotEmpty) ? 'pexels_photo:$c2' : 'pexels_photo';
      case 'pexels_video':
        final c = w.config['categoryId'] as String?;
        return (c != null && c.isNotEmpty) ? 'pexels_video:$c' : 'pexels_video';
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
    Set<String> usedCuratedIds, {
    Map<String, PhotoCuratorMetric> photoMetrics = const {},
  }) {
    final specs = parseScreenLayoutWidgets(layoutJson);
    final out = <String, String>{};
    for (final w in specs) {
      if (w.type == 'pexels_photo_collage') {
        final template =
            (w.config['template'] as String?)?.trim() ??
            kCollageTemplateNineSquareAsymmetric;
        final poolName = _poolNameForWidget(w);
        if (poolName == null || poolName.isEmpty) {
          continue;
        }
        final pool = randomPools[poolName];
        if (pool == null || pool.isEmpty) {
          continue;
        }
        final n = collageSlotCount(template);
        if (n <= 0) {
          continue;
        }
        final aspectPick = assignPhotosToCollageSlots(
          templateId: template,
          choiceKey: w.choiceKey,
          pool: pool,
          reserved: usedCuratedIds,
          photoMetrics: photoMetrics,
          random: random,
        );
        if (aspectPick != null) {
          for (final e in aspectPick.entries) {
            out[e.key] = e.value;
            usedCuratedIds.add(e.value);
          }
        }
        for (var i = 0; i < n; i++) {
          final k = '${w.choiceKey}_$i';
          if ((out[k] ?? '').isNotEmpty) {
            continue;
          }
          final choice = _pickUnusedFromPool(pool, random, usedCuratedIds);
          if (choice != null) {
            out[k] = choice;
          }
        }
        continue;
      }
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
      if (w.type == 'rss_article_stack') {
        final poolName = _poolNameForWidget(w);
        if (poolName == null || poolName.isEmpty) {
          continue;
        }
        for (var i = 0; i < 2; i++) {
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

class _NewsAssignment {
  _NewsAssignment({
    required this.screen,
    required this.choices,
    required this.cost,
  });

  final ScreenCandidate screen;
  final Map<String, String> choices;
  final double cost;
}

abstract class _PickOption {
  const _PickOption(this.screen);

  final ScreenCandidate screen;
}

final class _PickOptionNonNews extends _PickOption {
  const _PickOptionNonNews(super.screen);
}

final class _PickOptionNewsJoint extends _PickOption {
  const _PickOptionNewsJoint(super.screen, this.assignment);

  final _NewsAssignment assignment;
}
