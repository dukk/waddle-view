import 'package:drift/drift.dart';

import '../blob/blob_store.dart';
import 'database.dart';

/// Operator hard-delete of ingested catalog rows (distinct from suppression).
class ContentDeletionRepository {
  ContentDeletionRepository(this._db, {BlobStore? blobs}) : _blobs = blobs;

  final AppDatabase _db;
  final BlobStore? _blobs;

  Future<int> deleteJoke(String id) {
    return (_db.delete(_db.jokes)..where((t) => t.id.equals(id))).go();
  }

  Future<int> deleteQuoterismQuote(String id) async {
    final row = await (_db.select(_db.quoterismQuotes)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) {
      return 0;
    }
    await _deleteBlobByKey(row.authorImageBlobKey);
    await (_db.delete(_db.quoterismQuoteCategories)
          ..where((t) => t.quoteId.equals(id)))
        .go();
    return (_db.delete(_db.quoterismQuotes)..where((t) => t.id.equals(id))).go();
  }

  Future<int> deleteTriviaQuestion(String id) {
    return (_db.delete(
      _db.triviaQuestions,
    )..where((t) => t.id.equals(id))).go();
  }

  Future<int> deleteRssArticle(String id) async {
    final row = await (_db.select(
      _db.news,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) {
      return 0;
    }
    await _deleteBlobByKey(row.imageBlobKey);
    return (_db.delete(_db.news)..where((t) => t.id.equals(id))).go();
  }

  Future<int> deletePhoto(String id) async {
    final row = await (_db.select(
      _db.photos,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) {
      return 0;
    }
    await _deleteBlobByKey(row.mediaBlobKey);
    return (_db.delete(_db.photos)..where((t) => t.id.equals(id))).go();
  }

  Future<int> deleteVideo(String id) async {
    final row = await (_db.select(
      _db.videos,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) {
      return 0;
    }
    await _deleteBlobByKey(row.mediaBlobKey);
    return (_db.delete(_db.videos)..where((t) => t.id.equals(id))).go();
  }

  Future<int> deleteCalendarEvent(String id) {
    return (_db.delete(_db.calendarEvents)..where((t) => t.id.equals(id))).go();
  }

  Future<int> deleteStockQuote(String symbolId) {
    return (_db.delete(
      _db.stockQuotes,
    )..where((t) => t.symbolId.equals(symbolId))).go();
  }

  Future<int> deleteWeatherCurrent(String locationId) async {
    final row = await (_db.select(
      _db.weatherCurrent,
    )..where((t) => t.locationId.equals(locationId))).getSingleOrNull();
    if (row == null) {
      return 0;
    }
    await _deleteBlobByKey(row.currentIconBlobKey);
    return (_db.delete(
      _db.weatherCurrent,
    )..where((t) => t.locationId.equals(locationId))).go();
  }

  Future<int> deleteWeatherAlert(String locationId, String nwsAlertId) {
    return (_db.delete(_db.weatherAlerts)..where(
          (t) =>
              t.locationId.equals(locationId) & t.nwsAlertId.equals(nwsAlertId),
        ))
        .go();
  }

  Future<void> _deleteBlobByKey(String? key) async {
    if (key == null || key.isEmpty || _blobs == null) {
      return;
    }
    final meta = await (_db.select(
      _db.blobMetadata,
    )..where((t) => t.blobKey.equals(key))).getSingleOrNull();
    if (meta == null) {
      return;
    }
    await _blobs.delete(BlobRef(meta.relativePath));
    await (_db.delete(
      _db.blobMetadata,
    )..where((t) => t.blobKey.equals(key))).go();
  }
}
