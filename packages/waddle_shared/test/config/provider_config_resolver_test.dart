import 'package:drift/drift.dart' show Value;
import 'package:test/test.dart';

import 'package:waddle_shared/config/provider_access_token_env.dart';
import 'package:waddle_shared/config/provider_config_resolver.dart';
import 'package:waddle_shared/persistence/database.dart';

import '../helpers/memory_database.dart';

void main() {
  test('merges drift row with env token', () async {
    final db = openMemoryDatabase();
    await warmDatabase(db);
    await db.into(db.providerSettings).insert(
          ProviderSettingsCompanion.insert(
            id: 'p1',
            providerType: 't',
            baseUrl: const Value('https://example.com'),
          ),
        );
    final env = {waddleProviderAccessTokenEnvKey('p1'): 'tok'};
    final resolver = ProviderConfigResolver(db, env);
    final cfg = await resolver.resolve('p1');
    expect(cfg.accessToken, 'tok');
    expect(cfg.baseUrl, 'https://example.com');
    expect(cfg.describeForLogs(), contains('<redacted>'));
    await db.close();
  });
}
