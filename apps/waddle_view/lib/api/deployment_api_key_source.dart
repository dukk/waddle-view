import 'dart:io';

/// Loads the deployment REST API key (single trimmed line).
abstract class DeploymentApiKeySource {
  Future<String?> load();
}

class FileDeploymentApiKeySource implements DeploymentApiKeySource {
  FileDeploymentApiKeySource(this.file);

  final File file;

  @override
  Future<String?> load() async {
    if (!await file.exists()) {
      return null;
    }
    final raw = await file.readAsString();
    final line = raw.trim();
    return line.isEmpty ? null : line;
  }
}

class FakeDeploymentApiKeySource implements DeploymentApiKeySource {
  FakeDeploymentApiKeySource(this.value);

  String? value;

  @override
  Future<String?> load() async => value;
}
