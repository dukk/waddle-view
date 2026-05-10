import 'dart:async';

import 'package:drift/drift.dart';

/// Each test that calls `openMemoryDatabase` constructs a new [AppDatabase]
/// against a fresh in-memory `NativeDatabase`, so the drift "multiple instances
/// against the same QueryExecutor" warning is benign here. Silence it once for
/// the whole suite to keep CI logs readable.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  await testMain();
}
