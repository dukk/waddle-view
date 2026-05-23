import 'dart:convert';

const int kDefaultTasksTrelloRequestTimeoutMs = 15000;

class TasksTrelloProviderExtraConfig {
  const TasksTrelloProviderExtraConfig({
    required this.boardIds,
    required this.requestTimeoutMs,
  });

  final List<String> boardIds;
  final int requestTimeoutMs;

  static TasksTrelloProviderExtraConfig parse(String? configJson) {
    if (configJson == null || configJson.trim().isEmpty) {
      return const TasksTrelloProviderExtraConfig(
        boardIds: [],
        requestTimeoutMs: kDefaultTasksTrelloRequestTimeoutMs,
      );
    }
    try {
      final decoded = jsonDecode(configJson);
      if (decoded is! Map) {
        return parse(null);
      }
      final m = Map<String, dynamic>.from(decoded);
      final boardsRaw = m['boardIds'];
      final boards = <String>[];
      if (boardsRaw is List) {
        for (final entry in boardsRaw) {
          final id = entry?.toString().trim() ?? '';
          if (id.isNotEmpty) {
            boards.add(id);
          }
        }
      }
      final timeoutRaw = m['requestTimeoutMs'];
      final timeout = (timeoutRaw is num && timeoutRaw.toInt() >= 1000)
          ? timeoutRaw.toInt()
          : kDefaultTasksTrelloRequestTimeoutMs;
      return TasksTrelloProviderExtraConfig(
        boardIds: List.unmodifiable(boards),
        requestTimeoutMs: timeout,
      );
    } on Object {
      return parse(null);
    }
  }
}
