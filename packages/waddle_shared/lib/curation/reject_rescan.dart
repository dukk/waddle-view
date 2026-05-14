import 'package:drift/drift.dart' show Value;

import '../persistence/database.dart';
import 'reject_filter.dart';
import 'reject_filter_context.dart';

/// Result of a single [rescanContentForBlockTerms] pass.
class RejectRescanResult {
  const RejectRescanResult({
    required this.rssArticlesMarked,
    required this.jokesMarked,
    required this.triviaQuestionsMarked,
    required this.photosMarked,
    required this.videosMarked,
  });

  /// New rows the helper marked `suppressed = true` during this pass. Already-
  /// suppressed rows are skipped (so repeated calls are idempotent).
  final int rssArticlesMarked;
  final int jokesMarked;
  final int triviaQuestionsMarked;
  final int photosMarked;
  final int videosMarked;

  int get totalMarked =>
      rssArticlesMarked +
      jokesMarked +
      triviaQuestionsMarked +
      photosMarked +
      videosMarked;
}

/// Re-evaluates every non-suppressed row in the content tables against the
/// current reject list and sets `suppressed = true` on:
///
/// - news / joke / trivia rows that contain any [RejectFilterTerm] with
///   `action == 'block'`,
/// - photo / video rows whose photographer name, alt text, or any URL field
///   matches ANY term (block or censor) per [mediaMatchesAnyTerm].
///
/// Removing a term does NOT clear `suppressed`; operators use the per-row
/// content-suppression endpoints to undo manual suppressions.
Future<RejectRescanResult> rescanContentForBlockTerms(AppDatabase db) async {
  final ctx = await RejectFilterContext.loadFromDb(db);
  if (ctx.isEmpty) {
    return const RejectRescanResult(
      rssArticlesMarked: 0,
      jokesMarked: 0,
      triviaQuestionsMarked: 0,
      photosMarked: 0,
      videosMarked: 0,
    );
  }

  var rssN = 0;
  final articles = await (db.select(db.rssArticles)
        ..where((t) => t.suppressed.equals(false)))
      .get();
  for (final a in articles) {
    if (ctx.isBlockedAny([a.title, a.summary])) {
      await (db.update(db.rssArticles)..where((t) => t.id.equals(a.id)))
          .write(const RssArticlesCompanion(suppressed: Value(true)));
      rssN++;
    }
  }

  var jokesN = 0;
  final jokes = await (db.select(db.jokes)
        ..where((t) => t.suppressed.equals(false)))
      .get();
  for (final j in jokes) {
    if (ctx.isBlockedAny(['${j.setup} ${j.punchline}'])) {
      await (db.update(db.jokes)..where((t) => t.id.equals(j.id)))
          .write(const JokesCompanion(suppressed: Value(true)));
      jokesN++;
    }
  }

  var triviaN = 0;
  final trivia = await (db.select(db.triviaQuestions)
        ..where((t) => t.suppressed.equals(false)))
      .get();
  for (final q in trivia) {
    if (ctx.isBlockedAny([
      q.question,
      q.optionA,
      q.optionB,
      q.optionC,
      q.optionD,
    ])) {
      await (db.update(db.triviaQuestions)..where((t) => t.id.equals(q.id)))
          .write(const TriviaQuestionsCompanion(suppressed: Value(true)));
      triviaN++;
    }
  }

  var photosN = 0;
  final photos = await (db.select(db.photos)
        ..where((t) => t.suppressed.equals(false)))
      .get();
  for (final p in photos) {
    if (ctx.isMediaRejected(
      photographer: p.photographerName,
      altText: p.altText,
      urls: [p.photographerUrl, p.pexelsPageUrl],
    )) {
      await (db.update(db.photos)..where((t) => t.id.equals(p.id)))
          .write(const PhotosCompanion(suppressed: Value(true)));
      photosN++;
    }
  }

  var videosN = 0;
  final videos = await (db.select(db.videos)
        ..where((t) => t.suppressed.equals(false)))
      .get();
  for (final v in videos) {
    if (ctx.isMediaRejected(
      photographer: v.photographerName,
      altText: v.altText,
      urls: [v.photographerUrl, v.pexelsPageUrl],
    )) {
      await (db.update(db.videos)..where((t) => t.id.equals(v.id)))
          .write(const VideosCompanion(suppressed: Value(true)));
      videosN++;
    }
  }

  return RejectRescanResult(
    rssArticlesMarked: rssN,
    jokesMarked: jokesN,
    triviaQuestionsMarked: triviaN,
    photosMarked: photosN,
    videosMarked: videosN,
  );
}
