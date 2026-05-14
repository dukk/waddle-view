import 'package:test/test.dart';
import 'package:waddlectl/backup_manifest.dart';

void main() {
  test('manifest round-trip', () {
    const json =
        '{"waddle_backup_version":1,"include_database":true,'
        '"include_blobs":false,"include_secrets":true,'
        '"waddlectl_version":"9.9.9","created_at_utc":"x",'
        '"sqlite_basename":"custom.sqlite"}\n';
    final m = WaddleBackupManifest.parseJson(json);
    expect(m.includeDatabase, isTrue);
    expect(m.includeBlobs, isFalse);
    expect(m.includeSecrets, isTrue);
    expect(m.sqliteBasename, 'custom.sqlite');
    expect(m.dbArchivePath, 'db/custom.sqlite');
    final again = WaddleBackupManifest.parseJson(m.encodeJson());
    expect(again.includeDatabase, m.includeDatabase);
    expect(again.sqliteBasename, m.sqliteBasename);
  });

  test('rejects bad version', () {
    expect(
      () => WaddleBackupManifest.parseJson(
        '{"waddle_backup_version":99,"include_database":true,'
        '"include_blobs":true,"include_secrets":true,'
        '"waddlectl_version":"1","created_at_utc":"",'
        '"sqlite_basename":"waddle_view.sqlite"}',
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
