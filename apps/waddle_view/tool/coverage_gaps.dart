// ignore_for_file: avoid_print
import 'dart:io';

bool _include(String sf) {
  final n = sf.replaceAll('\\', '/');
  if (!n.startsWith('lib/')) return false;
  if (n.endsWith('.g.dart')) return false;
  if (n.endsWith('persistence/tables.dart')) return false;
  if (n.endsWith('main.dart')) return false;
  return true;
}

void main() {
  final raw = File('coverage/lcov.info').readAsStringSync();
  final rows = <List<Object>>[];
  for (final b in raw.split('end_of_record')) {
    String? sf;
    var lf = 0, lh = 0;
    for (final line in b.split('\n')) {
      if (line.startsWith('SF:')) sf = line.substring(3).trim();
      if (line.startsWith('LF:')) lf = int.parse(line.substring(3).trim());
      if (line.startsWith('LH:')) lh = int.parse(line.substring(3).trim());
    }
    if (sf != null && _include(sf.replaceAll('\\', '/'))) {
      rows.add([lf - lh, lf, lh, sf]);
    }
  }
  rows.sort((a, b) => (b[0] as int).compareTo(a[0] as int));
  for (final r in rows.take(25)) {
    final miss = r[0] as int;
    if (miss <= 0) break;
    final lf = r[1] as int;
    final lh = r[2] as int;
    print(
      '${miss.toString().padLeft(4)} miss  ${(100 * lh / lf).toStringAsFixed(0).padLeft(3)}%  ${r[3]}',
    );
  }
}
