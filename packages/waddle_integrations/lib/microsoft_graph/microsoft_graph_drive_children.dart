import 'dart:convert';

import 'package:http/http.dart' as http;

import 'microsoft_graph_base_url.dart';

/// One child item under a OneDrive folder (folders only in operator picker).
class MicrosoftGraphDriveChild {
  const MicrosoftGraphDriveChild({
    required this.id,
    required this.name,
    required this.path,
    required this.isFolder,
  });

  final String id;
  final String name;

  /// Root-relative path including this item (`/Pictures` or `/Pictures/Kids`).
  final String path;
  final bool isFolder;
}

/// Lists immediate children under [folderPath] (`""` = drive root).
Future<List<MicrosoftGraphDriveChild>> listMicrosoftGraphDriveChildren({
  required http.Client httpClient,
  required String graphBaseUrl,
  required String accessToken,
  required String folderPath,
}) async {
  final graphBase = normalizeMicrosoftGraphBaseUrl(graphBaseUrl);
  final normalized = folderPath.trim().replaceFirst(RegExp(r'^/+'), '');
  final uri = normalized.isEmpty
      ? Uri.parse('$graphBase/me/drive/root/children')
      : Uri.parse(
          '$graphBase/me/drive/root:/${_encodeDrivePath(normalized)}:/children',
        );
  final out = <MicrosoftGraphDriveChild>[];
  var url = uri.replace(
    queryParameters: {
      r'$top': '200',
      r'$select': 'id,name,folder,parentReference',
    },
  ).toString();
  while (true) {
    final res = await httpClient.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (res.statusCode != 200) {
      throw MicrosoftGraphDriveChildrenException(
        statusCode: res.statusCode,
        body: res.body,
      );
    }
    final m = jsonDecode(res.body) as Map<String, dynamic>;
    final values = m['value'];
    if (values is List<dynamic>) {
      for (final raw in values) {
        if (raw is! Map<String, dynamic>) {
          continue;
        }
        final id = raw['id'];
        final name = raw['name'];
        if (id is! String || id.isEmpty || name is! String || name.isEmpty) {
          continue;
        }
        final isFolder = raw['folder'] is Map<String, dynamic>;
        final path = _childPath(normalized, name);
        out.add(
          MicrosoftGraphDriveChild(
            id: id,
            name: name,
            path: path,
            isFolder: isFolder,
          ),
        );
      }
    }
    final next = m['@odata.nextLink'];
    if (next is String && next.isNotEmpty) {
      url = next;
    } else {
      break;
    }
  }
  out.sort((a, b) {
    if (a.isFolder != b.isFolder) {
      return a.isFolder ? -1 : 1;
    }
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return out;
}

String _encodeDrivePath(String raw) {
  final trimmed = raw.trim().replaceFirst(RegExp(r'^/+'), '');
  if (trimmed.isEmpty) {
    return '';
  }
  return trimmed
      .split('/')
      .where((s) => s.isNotEmpty)
      .map(Uri.encodeComponent)
      .join('/');
}

String _childPath(String parentNormalized, String name) {
  final segment = name.trim();
  if (parentNormalized.isEmpty) {
    return '/$segment';
  }
  return '/$parentNormalized/$segment';
}

/// Graph list-children request failed.
class MicrosoftGraphDriveChildrenException implements Exception {
  MicrosoftGraphDriveChildrenException({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final String body;

  @override
  String toString() => 'MicrosoftGraphDriveChildrenException($statusCode)';
}
