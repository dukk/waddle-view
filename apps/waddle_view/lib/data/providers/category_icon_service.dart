import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;

import '../../data/data_write_context.dart';
import '../../debug/app_debug_log.dart';
import '../../persistence/database.dart';

const String kDefaultCategoryIconImageModel = 'gpt-image-1';

typedef CategoryIconSeed = ({String id, String label});

Future<void> ensureCategoryIcons({
  required DataWriteContext ctx,
  required http.Client httpClient,
  required String baseUrl,
  required String token,
  required String categoryType,
  required Iterable<CategoryIconSeed> categories,
  int? limit,
}) async {
  if (token.trim().isEmpty) {
    return;
  }

  final capped = limit == null
      ? categories.toList()
      : categories.take(limit).toList(growable: false);
  for (final category in capped) {
    final exists = await _hasCategoryIcon(
      db: ctx.db,
      categoryType: categoryType,
      categoryId: category.id,
    );
    if (exists) {
      continue;
    }

    try {
      final prompt = _iconPrompt(categoryType: categoryType, label: category.label);
      final bytes = await _generateCategoryIconPng(
        httpClient: httpClient,
        baseUrl: baseUrl,
        token: token,
        prompt: prompt,
      );
      if (bytes == null || bytes.isEmpty) {
        continue;
      }

      final ref = await ctx.blobs.putBytes(
        bytes,
        logicalKey: 'category_icon/$categoryType/${category.id}',
      );
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      await ctx.db.into(ctx.db.blobMetadata).insertOnConflictUpdate(
            BlobMetadataCompanion.insert(
              blobKey: ref.storageKey,
              sha256: ref.storageKey.split('/').last,
              relativePath: ref.storageKey,
              bytes: bytes.length,
              mimeType: const Value('image/png'),
              capturedAt: nowMs,
            ),
          );
      await ctx.db.customStatement(
        'INSERT INTO category_icons '
        '(category_type, category_id, blob_key, prompt, generated_by, updated_at_ms) '
        'VALUES (?, ?, ?, ?, ?, ?) '
        'ON CONFLICT(category_type, category_id) DO UPDATE SET '
        'blob_key = excluded.blob_key, '
        'prompt = excluded.prompt, '
        'generated_by = excluded.generated_by, '
        'updated_at_ms = excluded.updated_at_ms',
        [
          categoryType,
          category.id,
          ref.storageKey,
          prompt,
          'openai',
          nowMs,
        ],
      );
    } on Object catch (e, st) {
      AppDebugLog.engineFail(
        'ensureCategoryIcons categoryType=$categoryType categoryId=${category.id}',
        e,
        st,
      );
    }
  }
}

Future<void> preloadSeedCategoryIcons({
  required DataWriteContext ctx,
  required http.Client httpClient,
  int perTypeLimit = 3,
}) async {
  await _preloadType(
    ctx: ctx,
    httpClient: httpClient,
    providerId: 'jokes',
    categoryType: 'joke',
    rows: await ctx.db.select(ctx.db.jokeCategories).get(),
    perTypeLimit: perTypeLimit,
    idOf: (row) => row.id,
    labelOf: (row) => row.label,
  );
  await _preloadType(
    ctx: ctx,
    httpClient: httpClient,
    providerId: 'trivia',
    categoryType: 'trivia',
    rows: await ctx.db.select(ctx.db.triviaCategories).get(),
    perTypeLimit: perTypeLimit,
    idOf: (row) => row.id,
    labelOf: (row) => row.label,
  );
}

Future<void> _preloadType<T>({
  required DataWriteContext ctx,
  required http.Client httpClient,
  required String providerId,
  required String categoryType,
  required List<T> rows,
  required int perTypeLimit,
  required String Function(T row) idOf,
  required String Function(T row) labelOf,
}) async {
  try {
    final cfg = await ctx.resolveConfig(providerId);
    final token = cfg.accessToken;
    if (token == null || token.trim().isEmpty) {
      return;
    }
    final baseUrl =
        (cfg.baseUrl != null && cfg.baseUrl!.trim().isNotEmpty)
            ? cfg.baseUrl!.trim()
            : 'https://api.openai.com/v1';
    await ensureCategoryIcons(
      ctx: ctx,
      httpClient: httpClient,
      baseUrl: baseUrl,
      token: token,
      categoryType: categoryType,
      categories: rows.map((r) => (id: idOf(r), label: labelOf(r))),
      limit: perTypeLimit,
    );
  } on Object catch (e, st) {
    AppDebugLog.engineFail('preloadSeedCategoryIcons $providerId', e, st);
  }
}

Future<bool> _hasCategoryIcon({
  required AppDatabase db,
  required String categoryType,
  required String categoryId,
}) async {
  final rows = await db.customSelect(
    'SELECT 1 AS ok FROM category_icons '
    'WHERE category_type = ? AND category_id = ? LIMIT 1',
    variables: [
      Variable<String>(categoryType),
      Variable<String>(categoryId),
    ],
  ).get();
  return rows.isNotEmpty;
}

String _iconPrompt({required String categoryType, required String label}) {
  final bucket = categoryType == 'trivia' ? 'trivia question' : 'joke';
  return 'Create a simple, bold, family-friendly square icon that represents '
      'the $bucket category "$label". Flat vector style, centered subject, '
      'high contrast, no text, no watermark, transparent or plain background.';
}

Future<List<int>?> _generateCategoryIconPng({
  required http.Client httpClient,
  required String baseUrl,
  required String token,
  required String prompt,
}) async {
  final uri = Uri.parse('${baseUrl.trim()}/images/generations');
  final payload = <String, Object?>{
    'model': kDefaultCategoryIconImageModel,
    'prompt': prompt,
    'size': '256x256',
    'response_format': 'b64_json',
  };
  final res = await httpClient.post(
    uri,
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
    body: jsonEncode(payload),
  );
  if (res.statusCode != 200) {
    return null;
  }
  final decoded = jsonDecode(res.body);
  if (decoded is! Map<String, dynamic>) {
    return null;
  }
  final data = decoded['data'];
  if (data is! List || data.isEmpty) {
    return null;
  }
  final first = data.first;
  if (first is! Map<String, dynamic>) {
    return null;
  }
  final b64 = first['b64_json'];
  if (b64 is! String || b64.isEmpty) {
    return null;
  }
  return base64Decode(b64);
}
