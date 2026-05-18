import 'package:test/test.dart';
import 'package:waddle_shared/config/integration_config_json.dart';

void main() {
  test('reads baseUrl from config_json', () {
    expect(
      integrationBaseUrlFromConfigJson('{"baseUrl":"https://example.com"}'),
      'https://example.com',
    );
    expect(integrationBaseUrlFromConfigJson('{}'), isNull);
  });

  test('mergeBaseUrlIntoIntegrationConfig preserves existing baseUrl', () {
    expect(
      mergeBaseUrlIntoIntegrationConfig(
        '{"baseUrl":"https://config.test","a":1}',
        'https://column.test',
      ),
      '{"baseUrl":"https://config.test","a":1}',
    );
  });

  test('mergeBaseUrlIntoIntegrationConfig adds column value when missing', () {
    final merged = mergeBaseUrlIntoIntegrationConfig(
      '{"a":1}',
      'https://column.test',
    );
    expect(merged, contains('"baseUrl":"https://column.test"'));
  });

  test('setBaseUrlInIntegrationConfig updates or removes key', () {
    expect(
      setBaseUrlInIntegrationConfig('{"a":1}', 'https://new.test'),
      '{"a":1,"baseUrl":"https://new.test"}',
    );
    expect(
      setBaseUrlInIntegrationConfig(
        '{"baseUrl":"https://old.test"}',
        null,
      ),
      '{}',
    );
  });
}
