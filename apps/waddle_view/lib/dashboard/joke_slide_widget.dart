import 'dart:async';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/drift.dart' show CustomExpression, OrderingTerm;
import 'package:flutter/material.dart';

import '../blob/blob_store.dart';
import '../curator/screen_layout_parse.dart';
import '../curator/screen_program_curator.dart';
import '../persistence/database.dart';
import 'joke_slide_timing.dart';
import 'dashboard_viewport_scope.dart';

/// One random joke from [db], optional [categoryId] from [spec] `config`.
Future<Joke?> _loadRandomJoke(
  AppDatabase db,
  ParsedWidgetSpec spec,
) async {
  final categoryId = spec.config['categoryId'] as String?;
  final q = db.select(db.jokes);
  if (categoryId != null && categoryId.isNotEmpty) {
    q.where((t) => t.categoryId.equals(categoryId));
  }
  return (q
        ..orderBy([
          (t) => OrderingTerm(expression: const CustomExpression('random()')),
        ])
        ..limit(1))
      .getSingleOrNull();
}

Future<Uint8List?> _loadJokeCategoryIconBytes(
  AppDatabase db,
  BlobStore blobs,
  Joke joke,
) async {
  final rows = await db.customSelect(
    'SELECT bm.relative_path FROM category_icons ci '
    'JOIN blob_metadata bm ON bm.blob_key = ci.blob_key '
    'WHERE ci.category_type = ? AND ci.category_id = ? '
    'LIMIT 1',
    variables: [
      const Variable<String>('joke'),
      Variable<String>(joke.categoryId),
    ],
  ).get();
  if (rows.isEmpty) {
    return null;
  }
  final relativePath = rows.first.read<String>('relative_path');
  final bytes = await blobs.readBytes(BlobRef(relativePath));
  if (bytes.isEmpty) {
    return null;
  }
  return Uint8List.fromList(bytes);
}

/// Shows joke setup, then punchline after half of [slide.dwellMs].
class JokeSlideWidget extends StatefulWidget {
  const JokeSlideWidget({
    super.key,
    required this.db,
    required this.blobs,
    required this.slide,
    required this.spec,
    required this.theme,
  });

  final AppDatabase db;
  final BlobStore blobs;
  final ResolvedSlide slide;
  final ParsedWidgetSpec spec;
  final ThemeData theme;

  @override
  State<JokeSlideWidget> createState() => _JokeSlideWidgetState();
}

class _JokeSlideWidgetState extends State<JokeSlideWidget> {
  Joke? _joke;
  Uint8List? _categoryIconBytes;
  bool _loading = true;
  bool _showPunchline = false;
  Timer? _punchlineTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    final joke = await _loadRandomJoke(widget.db, widget.spec);
    final iconBytes = joke == null
        ? null
        : await _loadJokeCategoryIconBytes(widget.db, widget.blobs, joke);
    if (!mounted) {
      return;
    }
    setState(() {
      _joke = joke;
      _categoryIconBytes = iconBytes;
      _loading = false;
    });
    _schedulePunchlineReveal();
  }

  void _schedulePunchlineReveal() {
    _punchlineTimer?.cancel();
    if (_joke == null) {
      return;
    }
    final delayMs = punchlineDelayMs(widget.slide.dwellMs);
    if (delayMs <= 0) {
      setState(() {
        _showPunchline = true;
      });
      return;
    }
    _punchlineTimer = Timer(Duration(milliseconds: delayMs), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _showPunchline = true;
      });
    });
  }

  @override
  void dispose() {
    _punchlineTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final s = DashboardViewportScope.scaleOf(context);
    if (_loading) {
      return Padding(
        padding: EdgeInsets.all(24 * s),
        child: Center(
          child: SizedBox(
            width: 32 * s,
            height: 32 * s,
            child: const CircularProgressIndicator(),
          ),
        ),
      );
    }
    if (_joke == null) {
      return Padding(
        padding: EdgeInsets.only(bottom: 12 * s),
        child: Text(
          'No jokes yet',
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: 12 * s),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_categoryIconBytes != null) ...[
            Image.memory(
              _categoryIconBytes!,
              key: const ValueKey<String>('joke_category_icon'),
              width: 88 * s,
              height: 88 * s,
              fit: BoxFit.contain,
            ),
            SizedBox(height: 12 * s),
          ],
          Text(
            _joke!.setup,
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16 * s),
          AnimatedOpacity(
            opacity: _showPunchline ? 1 : 0,
            duration: const Duration(milliseconds: 320),
            child: Text(
              _joke!.punchline,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
