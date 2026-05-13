import 'dart:convert';
import 'dart:io';

import '../global_options.dart';

/// Human-readable vs JSON output for stdout.
class CliEmit {
  CliEmit(this.options);

  final GlobalCliOptions options;

  void emitJsonOrText(Object? data) {
    if (options.outputJson) {
      stdout.writeln(const JsonEncoder.withIndent(' ').convert(data));
    } else if (data != null) {
      if (data is Map) {
        final m = Map<String, Object?>.from(data);
        for (final e in m.entries) {
          stdout.writeln('${e.key}: ${e.value}');
        }
      } else {
        stdout.writeln('$data');
      }
    }
  }

  void emitRows(
    List<Map<String, Object?>> rows, {
    String wrapperKey = 'items',
  }) {
    if (options.outputJson) {
      stdout.writeln(
        const JsonEncoder.withIndent(' ').convert({wrapperKey: rows}),
      );
    } else {
      for (final r in rows) {
        stdout.writeln(r.entries.map((e) => '${e.key}=${e.value}').join('\t'));
      }
    }
  }

  void emitText(String line) {
    if (!options.outputJson) {
      stdout.writeln(line);
    }
  }
}
