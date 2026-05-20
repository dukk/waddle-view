import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/blob/blob_store.dart';
import 'package:waddle_shared/collect/collect_diagnostics.dart';
import 'package:waddle_shared/collect/data_collection_engine.dart';
import 'package:waddle_shared/collect/data_provider.dart';
import 'package:waddle_shared/collect/data_write_context.dart';
import 'package:waddle_shared/collect/integration_tagged_collect_diagnostics.dart';
import 'package:waddle_shared/collect/sleeper.dart';
import 'package:waddle_shared/config/provider_config_resolver.dart';
import 'package:waddle_shared/secrets/in_memory_secret_store.dart';

import '../helpers/memory_database.dart';

class _RecordingDiagnostics implements CollectDiagnostics {
  final List<({String kind, String message, String? integrationType})> lines =
      [];

  @override
  void engine(String message, {String? integrationType}) {
    lines.add((kind: 'engine', message: message, integrationType: integrationType));
  }

  @override
  void engineFail(
    String context,
    Object error,
    StackTrace stack, {
    String? integrationType,
  }) {
    lines.add((
      kind: 'engineFail',
      message: context,
      integrationType: integrationType,
    ));
  }

  @override
  void provider(String message, {String? integrationType}) {
    lines.add((
      kind: 'provider',
      message: message,
      integrationType: integrationType,
    ));
  }

  @override
  void providerFail(
    String context,
    Object error,
    StackTrace stack, {
    String? integrationType,
  }) {
    lines.add((
      kind: 'providerFail',
      message: context,
      integrationType: integrationType,
    ));
  }
}

class _MemBlobStore implements BlobStore {
  @override
  Future<void> delete(BlobRef ref) async {}

  @override
  Future<BlobRef> putBytes(List<int> bytes, {required String logicalKey}) async =>
      BlobRef('k');

  @override
  Future<List<int>> readBytes(BlobRef ref) async => const [];

  @override
  File? tryLocalFile(BlobRef ref) => null;
}

class _StopOnSleepSleeper implements Sleeper {
  _StopOnSleepSleeper(this._onSleep);

  final void Function() _onSleep;

  @override
  Future<void> sleep(Duration d) async {
    _onSleep();
  }
}

class _LoggingProvider implements IDataProvider {
  _LoggingProvider(this.typeId, this.onCollect);

  final String typeId;
  final void Function(DataWriteContext ctx) onCollect;

  @override
  String get id => typeId;

  @override
  Future<void> collect(DataWriteContext ctx) async {
    onCollect(ctx);
  }
}

void main() {
  test('IntegrationTaggedCollectDiagnostics defaults integrationType on provider', () {
    final base = _RecordingDiagnostics();
    final tagged = IntegrationTaggedCollectDiagnostics(
      base,
      integrationType: 'news_rss',
    );
    tagged.provider('inside collect');
    tagged.provider('override', integrationType: 'other');
    expect(base.lines.length, 2);
    expect(base.lines[0].integrationType, 'news_rss');
    expect(base.lines[1].integrationType, 'other');
  });

  test('DataCollectionEngine tags collect lines with provider id', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    final secrets = InMemorySecretStore();
    final resolver = ProviderConfigResolver(db, secrets);
    final diag = _RecordingDiagnostics();
    final provider = _LoggingProvider('photo_pexels', (ctx) {
      ctx.diagnostics.provider('pexels: tick');
    });
    final ctx = DataWriteContextImpl(
      db: db,
      blobs: _MemBlobStore(),
      secrets: secrets,
      resolve: resolver.resolve,
      diagnostics: diag,
    );
    DataCollectionEngine? engineRef;
    engineRef = DataCollectionEngine(
      providers: [provider],
      context: ctx,
      sleeper: _StopOnSleepSleeper(() => engineRef?.stop()),
      idleBetweenCycles: const Duration(days: 1),
      diagnostics: diag,
    );
    await engineRef.start();
    final providerLines = diag.lines.where((e) => e.kind == 'provider').toList();
    expect(
      providerLines.any(
        (e) =>
            e.message.contains('collect begin') &&
            e.integrationType == 'photo_pexels',
      ),
      isTrue,
    );
    expect(
      providerLines.any(
        (e) => e.message == 'pexels: tick' && e.integrationType == 'photo_pexels',
      ),
      isTrue,
    );
    expect(
      providerLines.any(
        (e) =>
            e.message.contains('collect ok') &&
            e.integrationType == 'photo_pexels',
      ),
      isTrue,
    );
    await db.close();
  });
}
