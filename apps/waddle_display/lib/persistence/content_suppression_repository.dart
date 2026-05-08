import 'package:drift/drift.dart';

import 'database.dart';

/// Operator-controlled hide flag (rows remain for stable provider ids).
class ContentSuppressionRepository {
  ContentSuppressionRepository(this._db);

  final AppDatabase _db;

  Future<int> setJokeSuppressed(String id, bool suppressed) {
    return (_db.update(_db.jokes)..where((t) => t.id.equals(id)))
        .write(JokesCompanion(suppressed: Value(suppressed)));
  }

  Future<int> setRssArticleSuppressed(String id, bool suppressed) {
    return (_db.update(_db.rssArticles)..where((t) => t.id.equals(id)))
        .write(RssArticlesCompanion(suppressed: Value(suppressed)));
  }

  Future<int> setPhotoSuppressed(String id, bool suppressed) {
    return (_db.update(_db.photos)..where((t) => t.id.equals(id)))
        .write(PhotosCompanion(suppressed: Value(suppressed)));
  }

  Future<int> setVideoSuppressed(String id, bool suppressed) {
    return (_db.update(_db.videos)..where((t) => t.id.equals(id)))
        .write(VideosCompanion(suppressed: Value(suppressed)));
  }

  Future<int> setTriviaQuestionSuppressed(String id, bool suppressed) {
    return (_db.update(_db.triviaQuestions)..where((t) => t.id.equals(id)))
        .write(TriviaQuestionsCompanion(suppressed: Value(suppressed)));
  }
}
