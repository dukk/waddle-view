import 'dart:collection';

import '../curator/screen_program_curator.dart';
import '../curator/ticker_item.dart';

/// In-process ring buffers for operator REST / UI (not persisted to SQLite).
final class OperatorTelemetryHub {
  OperatorTelemetryHub({
    this.maxProviderLines = 500,
    this.maxScreenPrograms = 50,
    this.maxTickerPrograms = 50,
  });

  final int maxProviderLines;
  final int maxScreenPrograms;
  final int maxTickerPrograms;

  final ListQueue<TelemetryTextLine> _providerLines = ListQueue();
  final ListQueue<ScreenProgramRecord> _screenPrograms = ListQueue();
  final ListQueue<TickerProgramRecord> _tickerPrograms = ListQueue();

  void addProviderLine(String message) {
    _appendLine(_providerLines, TelemetryTextLine(atMs: _nowMs(), channel: 'provider', message: message), maxProviderLines);
  }

  void addEngineLine(String message) {
    _appendLine(_providerLines, TelemetryTextLine(atMs: _nowMs(), channel: 'engine', message: message), maxProviderLines);
  }

  void addProviderFail(String context, Object error, StackTrace stack) {
    final msg =
        'FAIL $context: ${Error.safeToString(error)} '
        '(${_stackHead(stack)})';
    addProviderLine(msg);
  }

  void addEngineFail(String context, Object error, StackTrace stack) {
    final msg =
        'FAIL $context: ${Error.safeToString(error)} '
        '(${_stackHead(stack)})';
    addEngineLine(msg);
  }

  void recordScreenProgram({
    required String reason,
    required List<ResolvedSlide> slides,
    required Map<String, String> screenTypeById,
  }) {
    final slideMaps = <Map<String, Object?>>[
      for (final s in slides)
        <String, Object?>{
          'screen_id': s.screenId,
          'screen_type': screenTypeById[s.screenId],
          'dwell_ms': s.dwellMs,
          'layout_json': s.layoutJson,
          'random_choices': Map<String, String>.from(s.randomChoices),
        },
    ];
    _appendProgram(
      _screenPrograms,
      ScreenProgramRecord(atMs: _nowMs(), reason: reason, slides: slideMaps),
      maxScreenPrograms,
    );
  }

  void recordTickerProgram(List<TickerItem> items) {
    final itemMaps = <Map<String, Object?>>[for (final i in items) _tickerItemJson(i)];
    _appendProgram(
      _tickerPrograms,
      TickerProgramRecord(atMs: _nowMs(), items: itemMaps),
      maxTickerPrograms,
    );
  }

  List<Map<String, Object?>> snapshotProviderLines({int? limit, int? sinceMs}) {
    return _snapshotLines(_providerLines, limit: limit, sinceMs: sinceMs);
  }

  List<Map<String, Object?>> snapshotScreenPrograms({int? limit, int? sinceMs}) {
    return _snapshotPrograms(_screenPrograms, limit: limit, sinceMs: sinceMs);
  }

  List<Map<String, Object?>> snapshotTickerPrograms({int? limit, int? sinceMs}) {
    return _snapshotPrograms(_tickerPrograms, limit: limit, sinceMs: sinceMs);
  }
}

int _nowMs() => DateTime.now().millisecondsSinceEpoch;

String _stackHead(StackTrace stack) {
  final lines = stack.toString().trim().split('\n');
  return lines.isEmpty ? '' : lines.first.trim();
}

void _appendLine(ListQueue<TelemetryTextLine> q, TelemetryTextLine line, int max) {
  q.addLast(line);
  while (q.length > max) {
    q.removeFirst();
  }
}

void _appendProgram<T>(ListQueue<T> q, T record, int max) {
  q.addLast(record);
  while (q.length > max) {
    q.removeFirst();
  }
}

List<Map<String, Object?>> _snapshotLines(
  ListQueue<TelemetryTextLine> q, {
  int? limit,
  int? sinceMs,
}) {
  final list = q.toList();
  var filtered = list;
  if (sinceMs != null) {
    filtered = [for (final e in list) if (e.atMs >= sinceMs) e];
  }
  if (limit != null && limit < filtered.length) {
    filtered = filtered.sublist(filtered.length - limit);
  }
  return [for (final e in filtered) e.toJson()];
}

List<Map<String, Object?>> _snapshotPrograms<T extends _HasAtMs>(
  ListQueue<T> q, {
  int? limit,
  int? sinceMs,
}) {
  final list = q.toList();
  var filtered = list;
  if (sinceMs != null) {
    filtered = [for (final e in list) if (e.atMs >= sinceMs) e];
  }
  if (limit != null && limit < filtered.length) {
    filtered = filtered.sublist(filtered.length - limit);
  }
  return [for (final e in filtered) e.toJson()];
}

abstract final class _HasAtMs {
  int get atMs;
  Map<String, Object?> toJson();
}

final class TelemetryTextLine {
  TelemetryTextLine({
    required this.atMs,
    required this.channel,
    required this.message,
  });

  final int atMs;
  final String channel;
  final String message;

  Map<String, Object?> toJson() => {
    'at_ms': atMs,
    'channel': channel,
    'message': message,
  };
}

final class ScreenProgramRecord implements _HasAtMs {
  ScreenProgramRecord({
    required this.atMs,
    required this.reason,
    required this.slides,
  });

  @override
  final int atMs;
  final String reason;
  final List<Map<String, Object?>> slides;

  @override
  Map<String, Object?> toJson() => {
    'at_ms': atMs,
    'reason': reason,
    'slides': slides,
  };
}

final class TickerProgramRecord implements _HasAtMs {
  TickerProgramRecord({
    required this.atMs,
    required this.items,
  });

  @override
  final int atMs;
  final List<Map<String, Object?>> items;

  @override
  Map<String, Object?> toJson() => {
    'at_ms': atMs,
    'items': items,
  };
}

Map<String, Object?> _tickerItemJson(TickerItem i) {
  final rss = i.rss;
  return <String, Object?>{
    'kind': i.kind,
    'body': i.body,
    'source_id': i.sourceId,
    if (rss != null)
      'rss': <String, Object?>{
        'source_title': rss.sourceTitle,
        'article_title': rss.articleTitle,
        'summary': rss.summary,
        'show_source': rss.showSource,
        'source_icon_name': rss.sourceIconName,
      },
  };
}
