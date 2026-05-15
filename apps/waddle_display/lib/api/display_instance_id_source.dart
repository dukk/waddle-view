import 'dart:io';

/// Reads the per-display instance identifier from [waddle_instance.id].
abstract class DisplayInstanceIdSource {
  Future<String?> load();
}

class FileDisplayInstanceIdSource implements DisplayInstanceIdSource {
  FileDisplayInstanceIdSource(this.file);

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

/// Test double.
class FakeDisplayInstanceIdSource implements DisplayInstanceIdSource {
  FakeDisplayInstanceIdSource(this.value);

  final String? value;

  @override
  Future<String?> load() async => value;
}
