import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:waddle_shared/blob/blob_store.dart';
import 'package:waddle_shared/blob/display_blob_read.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import 'package:waddle_shared/persistence/database.dart';

import '../../../curator/screen_program_curator.dart';
import '../../content_category_slide_header.dart';
import '../../dashboard_viewport_scope.dart';
import '../../display_decode_image_bytes.dart';
import '../../display_memory_image.dart';
import '../../slide_content_quote.dart';

/// Inspirational quote with optional author portrait.
class QuoteSlideWidget extends StatefulWidget {
  const QuoteSlideWidget({
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
  State<QuoteSlideWidget> createState() => _QuoteSlideWidgetState();
}

class _QuoteSlideWidgetState extends State<QuoteSlideWidget> {
  QuoterismQuote? _quote;
  List<String> _categoryIds = const [];
  Uint8List? _authorBytes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    final quote = await loadQuoteForSlide(widget.db, widget.spec, widget.slide);
    List<String> cats = const [];
    Uint8List? bytes;
    if (quote != null) {
      final catRows = await (widget.db.select(
        widget.db.quoterismQuoteCategories,
      )..where((t) => t.quoteId.equals(quote.id))).get();
      cats = catRows.map((r) => r.categoryId).toList();
      final key = quote.authorImageBlobKey?.trim();
      if (key != null && key.isNotEmpty) {
        final meta = await (widget.db.select(
          widget.db.blobMetadata,
        )..where((t) => t.blobKey.equals(key))).getSingleOrNull();
        if (meta != null) {
          final read = await readDisplayBlobBytes(
            widget.blobs,
            BlobRef(meta.relativePath),
          );
          if (read.isOk && read.bytes != null) {
            final raw = read.bytes!;
            if (await canDecodeDisplayImageBytes(raw)) {
              bytes = raw;
            }
          }
        }
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _quote = quote;
      _categoryIds = cats;
      _authorBytes = bytes;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final s = DashboardViewportScope.scaleOf(context);
    final cfgCat = widget.spec.config['categoryId'] as String?;
    final headerCat = (cfgCat != null && cfgCat.isNotEmpty)
        ? cfgCat
        : (_categoryIds.isNotEmpty ? _categoryIds.first : null);

    if (_loading) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ContentCategorySlideHeader(
            db: widget.db,
            blobs: widget.blobs,
            theme: theme,
            categoryId: headerCat,
          ),
          Padding(
            padding: EdgeInsets.all(24 * s),
            child: Center(
              child: SizedBox(
                width: 32 * s,
                height: 32 * s,
                child: const CircularProgressIndicator(),
              ),
            ),
          ),
        ],
      );
    }

    if (_quote == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ContentCategorySlideHeader(
            db: widget.db,
            blobs: widget.blobs,
            theme: theme,
            categoryId: headerCat,
          ),
          Padding(
            padding: EdgeInsets.all(24 * s),
            child: Text(
              'No quotes available',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    final author = (_quote!.authorName ?? '').trim();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ContentCategorySlideHeader(
          db: widget.db,
          blobs: widget.blobs,
          theme: theme,
          categoryId: headerCat,
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 32 * s, vertical: 16 * s),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _quote!.quoteText,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  height: 1.35,
                ),
                textAlign: TextAlign.center,
              ),
              if (author.isNotEmpty || _authorBytes != null) ...[
                SizedBox(height: 20 * s),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_authorBytes != null)
                      ClipOval(
                        child: SizedBox(
                          width: 56 * s,
                          height: 56 * s,
                          child: DisplayMemoryImage(
                            bytes: _authorBytes!,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    if (_authorBytes != null && author.isNotEmpty)
                      SizedBox(width: 12 * s),
                    if (author.isNotEmpty)
                      Flexible(
                        child: Text(
                          author,
                          style: theme.textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
