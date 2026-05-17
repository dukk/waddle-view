import 'dart:convert';

/// JSON `waddle_backup_version` inside [WaddleBackupManifest].
const kWaddleBackupManifestVersion = 1;

const kBackupManifestPath = 'manifest.json';
const kBackupDbDir = 'db';
const kBackupSecretsBundlePath = 'secrets/secret_bundle.bin';

/// On-disk backup manifest (serialized to [kBackupManifestPath]).
class WaddleBackupManifest {
  WaddleBackupManifest({
    required this.includeDatabase,
    required this.includeBlobs,
    required this.includeSecrets,
    required this.waddlectlVersion,
    required this.createdAtUtcIso,
    this.sqliteBasename = 'waddle_display.db',
  });

  final bool includeDatabase;
  final bool includeBlobs;
  final bool includeSecrets;
  final String waddlectlVersion;
  final String createdAtUtcIso;
  final String sqliteBasename;

  String get dbArchivePath => '$kBackupDbDir/$sqliteBasename';

  Map<String, Object?> toJson() => {
    'waddle_backup_version': kWaddleBackupManifestVersion,
    'include_database': includeDatabase,
    'include_blobs': includeBlobs,
    'include_secrets': includeSecrets,
    'waddlectl_version': waddlectlVersion,
    'created_at_utc': createdAtUtcIso,
    'sqlite_basename': sqliteBasename,
  };

  String encodeJson() {
    final body = const JsonEncoder.withIndent(' ').convert(toJson());
    return '$body\n';
  }

  static WaddleBackupManifest parseJson(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('manifest: expected JSON object');
    }
    final m = decoded;
    final ver = m['waddle_backup_version'];
    if (ver is! int || ver != kWaddleBackupManifestVersion) {
      throw FormatException('unsupported waddle_backup_version: $ver');
    }
    return WaddleBackupManifest(
      includeDatabase: m['include_database'] == true,
      includeBlobs: m['include_blobs'] == true,
      includeSecrets: m['include_secrets'] == true,
      waddlectlVersion: m['waddlectl_version'] as String? ?? '',
      createdAtUtcIso: m['created_at_utc'] as String? ?? '',
      sqliteBasename: m['sqlite_basename'] as String? ?? 'waddle_display.db',
    );
  }
}
