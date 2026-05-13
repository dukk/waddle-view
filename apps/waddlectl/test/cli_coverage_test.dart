import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:waddlectl/run_app.dart';

/// Drives most `runWaddlectl` code paths for coverage (temp SQLite each time).
void main() {
  late String dbPath;

  setUp(() {
    final tmp = Directory.systemTemp.createTempSync('waddlectl_cov');
    dbPath = p.join(tmp.path, 'waddle_view.sqlite');
    File(dbPath).writeAsStringSync('');
  });

  tearDown(() {
    final f = File(dbPath);
    final dir = f.parent;
    try {
      if (f.existsSync()) {
        f.deleteSync();
      }
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    } on Object {
      // ignore
    }
  });

  List<String> w(List<String> tail) => ['--database', dbPath, ...tail];

  test('screens tickers providers curator config surface', () async {
    expect(await runWaddlectl(w(['screens', 'list'])), 0);
    expect(await runWaddlectl(w(['screens', 'describe', 'missing'])), 0);
    expect(await runWaddlectl(w(['tickers', 'list'])), 0);
    expect(await runWaddlectl(w(['tickers', 'describe', 'missing'])), 0);
    expect(await runWaddlectl(w(['providers', 'list'])), 0);
    expect(await runWaddlectl(w(['providers', 'describe', 'missing'])), 0);
    expect(await runWaddlectl(w(['curator', 'describe-program'])), 0);
    expect(
      await runWaddlectl(
        w(['curator', 'update-program', '--program-duration-seconds=120']),
      ),
      0,
    );
    expect(await runWaddlectl(w(['curator', 'limits', 'list'])), 0);
    expect(
      await runWaddlectl(w(['curator', 'limits', 'describe', 'missing'])),
      0,
    );
    expect(
      await runWaddlectl(
        w([
          'curator',
          'limits',
          'update',
          'news',
          '--min-placements-per-program=0',
        ]),
      ),
      0,
    );
    expect(await runWaddlectl(w(['config', 'list'])), 0);
  });

  test('invalid usage returns 64', () async {
    expect(await runWaddlectl(w(['config', 'get'])), 64);
  });

  test('secrets export/import usage errors return 64', () async {
    expect(await runWaddlectl(w(['secrets', 'export'])), 64);
    expect(
      await runWaddlectl(
        w(['secrets', 'export', '--file', p.join(dbPath, 'x.bin'), 'extra']),
      ),
      64,
    );
    expect(await runWaddlectl(w(['secrets', 'import'])), 64);
    expect(
      await runWaddlectl(
        w(['secrets', 'import', '--file', '/no/such/waddle_bundle.bin']),
      ),
      64,
    );
  });
}
