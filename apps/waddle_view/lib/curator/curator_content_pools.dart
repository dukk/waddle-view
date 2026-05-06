import '../persistence/database.dart';

/// IDs grouped for [ScreenProgramCurator.buildProgram] `randomPools`.
///
/// Keys: `joke`, `joke:<categoryId>`, `rss`, `rss:<feedId>`, `trivia`,
/// `trivia:<categoryId>`, `pexels_photo`, `pexels_photo:<category>`,
/// `pexels_video`, `pexels_video:<category>`.
Future<Map<String, List<String>>> loadCuratorContentPools(
  AppDatabase db,
) async {
  final out = <String, List<String>>{};

  final jokes = await db.select(db.jokes).get();
  if (jokes.isNotEmpty) {
    final all = <String>[];
    final byCat = <String, List<String>>{};
    for (final j in jokes) {
      all.add(j.id);
      (byCat[j.categoryId] ??= []).add(j.id);
    }
    out['joke'] = all;
    for (final e in byCat.entries) {
      out['joke:${e.key}'] = List<String>.from(e.value);
    }
  }

  final articles = await db.select(db.rssArticles).get();
  if (articles.isNotEmpty) {
    final all = <String>[];
    final byFeed = <String, List<String>>{};
    for (final a in articles) {
      all.add(a.id);
      (byFeed[a.feedId] ??= []).add(a.id);
    }
    out['rss'] = all;
    for (final e in byFeed.entries) {
      out['rss:${e.key}'] = List<String>.from(e.value);
    }
  }

  final trivia = await db.select(db.triviaQuestions).get();
  if (trivia.isNotEmpty) {
    final all = <String>[];
    final byCat = <String, List<String>>{};
    for (final q in trivia) {
      all.add(q.id);
      (byCat[q.categoryId] ??= []).add(q.id);
    }
    out['trivia'] = all;
    for (final e in byCat.entries) {
      out['trivia:${e.key}'] = List<String>.from(e.value);
    }
  }

  final pexelsPhotos = await db.select(db.photos).get();
  if (pexelsPhotos.isNotEmpty) {
    final all = <String>[];
    final byCat = <String, List<String>>{};
    for (final p in pexelsPhotos) {
      all.add(p.id);
      (byCat[p.category] ??= []).add(p.id);
    }
    out['pexels_photo'] = all;
    for (final e in byCat.entries) {
      out['pexels_photo:${e.key}'] = List<String>.from(e.value);
    }
  }

  final pexelsVideos = await db.select(db.videos).get();
  if (pexelsVideos.isNotEmpty) {
    final all = <String>[];
    final byCat = <String, List<String>>{};
    for (final v in pexelsVideos) {
      all.add(v.id);
      (byCat[v.category] ??= []).add(v.id);
    }
    out['pexels_video'] = all;
    for (final e in byCat.entries) {
      out['pexels_video:${e.key}'] = List<String>.from(e.value);
    }
  }

  return out;
}
