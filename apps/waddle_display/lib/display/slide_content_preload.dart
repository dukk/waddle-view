import 'package:waddle_shared/blob/blob_store.dart';
import '../curator/photo_collage_curation.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import '../curator/screen_program_curator.dart';
import 'package:waddle_shared/persistence/database.dart';
import 'screens/photo/photo_slide_media.dart';
import 'screens/photo/video_slide_widget.dart';
import 'screens/photo/photo_video_materialize.dart';
import 'screens/news/news_load.dart';
import 'screens/web_page/web_page_session.dart';
import 'slide_content_joke_trivia.dart';

/// Warms DB/blob/video file resources for every async widget on this slide so
/// mounted slide widgets hit warm caches and avoid loading spinners.
Future<void> preloadResolvedSlideContent({
  required AppDatabase db,
  required BlobStore blobs,
  required ResolvedSlide slide,
}) async {
  final widgets = parseScreenLayoutWidgets(slide.layoutJson);
  await Future.wait([
    for (final w in widgets) _preloadWidget(db, blobs, slide, w),
  ]);
}

Future<void> _preloadWidget(
  AppDatabase db,
  BlobStore blobs,
  ResolvedSlide slide,
  ParsedWidgetSpec w,
) async {
  switch (w.type) {
    case 'news':
      await _preloadRssArticle(db, blobs, slide, w);
    case 'news_columns':
      await _preloadRssColumns(db, blobs, slide, w);
    case 'news_stack':
      await _preloadRssStack(db, blobs, slide, w);
    case 'photo':
      await _preloadPhoto(db, blobs, slide, w);
    case 'photo_collage':
      await _preloadPexelsCollage(db, blobs, slide, w);
    case 'video':
      await _preloadPexelsVideo(db, blobs, slide, w);
    case 'joke':
      await loadJokeForSlide(db, w, slide);
    case 'trivia':
      await loadTriviaForSlide(db, w, slide);
    case 'web_page':
      await WebPagePrepareCache.instance.preload(w);
    default:
      return;
  }
}

Future<void> _preloadRssArticle(
  AppDatabase db,
  BlobStore blobs,
  ResolvedSlide slide,
  ParsedWidgetSpec w,
) async {
  final article = await loadRssArticleForSlideChoice(
    db,
    w,
    slide,
    w.choiceKey,
    const {},
  );
  if (article != null) {
    await loadRssArticleImage(db, blobs, article);
  }
  await resolveRssDisplayCategoryId(db, slide, article);
  await resolveRssArticleSourceLabel(db, article);
}

Future<void> _preloadRssColumns(
  AppDatabase db,
  BlobStore blobs,
  ResolvedSlide slide,
  ParsedWidgetSpec w,
) async {
  final n = w.rssSummarySlotCapacities.length.clamp(1, 6);
  final exclude = <String>{};
  NewsArticle? firstArticle;
  for (var i = 0; i < n; i++) {
    final key = '${w.choiceKey}_$i';
    final article = await loadRssArticleForSlideChoice(
      db,
      w,
      slide,
      key,
      exclude,
    );
    if (article != null) {
      exclude.add(article.id);
      await loadRssArticleImage(db, blobs, article);
      firstArticle ??= article;
    }
    await resolveRssArticleSourceLabel(db, article);
  }
  await resolveRssDisplayCategoryId(db, slide, firstArticle);
}

Future<void> _preloadRssStack(
  AppDatabase db,
  BlobStore blobs,
  ResolvedSlide slide,
  ParsedWidgetSpec w,
) async {
  final exclude = <String>{};
  final arts = <NewsArticle?>[];
  for (var i = 0; i < 2; i++) {
    final key = '${w.choiceKey}_$i';
    final article = await loadRssArticleForSlideChoice(
      db,
      w,
      slide,
      key,
      exclude,
    );
    arts.add(article);
    if (article != null) {
      exclude.add(article.id);
      await loadRssArticleImage(db, blobs, article);
    }
    await resolveRssArticleSourceLabel(db, article);
  }
  NewsArticle? firstForCategory;
  for (final a in arts) {
    if (a != null) {
      firstForCategory = a;
      break;
    }
  }
  await resolveRssDisplayCategoryId(db, slide, firstForCategory);
}

Future<void> _preloadPhoto(
  AppDatabase db,
  BlobStore blobs,
  ResolvedSlide slide,
  ParsedWidgetSpec w,
) async {
  final row = await loadPhotoForSlide(db, w, slide);
  if (row != null) {
    await loadPhotoBlobBytes(db, blobs, row);
  }
}

Future<void> _preloadPexelsCollage(
  AppDatabase db,
  BlobStore blobs,
  ResolvedSlide slide,
  ParsedWidgetSpec w,
) async {
  final raw =
      (w.config['template'] as String?)?.trim() ??
      kCollageTemplateNineSquareAsymmetric;
  final templateId = kKnownCollageTemplateIds.contains(raw)
      ? raw
      : kCollageTemplateNineSquareAsymmetric;
  final n = collageSlotCount(templateId);
  final choiceKey = w.choiceKey;
  await Future.wait(
    List.generate(n, (i) async {
      final id = slide.randomChoices['${choiceKey}_$i'];
      final row = await loadPhotoByCuratedId(db, id);
      if (row != null) {
        await loadPhotoBlobBytes(db, blobs, row);
      }
    }),
  );
}

Future<void> _preloadPexelsVideo(
  AppDatabase db,
  BlobStore blobs,
  ResolvedSlide slide,
  ParsedWidgetSpec w,
) async {
  final row = await loadPexelsVideoForSlide(db, w, slide);
  if (row != null) {
    try {
      await materializePexelsVideoFile(db, blobs, row);
    } catch (_) {
      // Missing or unreadable blob must not abort slide preload.
    }
  }
}
