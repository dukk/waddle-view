import 'package:http/http.dart' as http;

/// Builds download URL for a Picker photo [baseUrl] (full image, metadata stripped).
String googlePhotosPhotoDownloadUrl(String baseUrl) {
  if (baseUrl.contains('=')) {
    return baseUrl;
  }
  return '$baseUrl=d';
}

/// Builds download URL for a Picker video [baseUrl].
String googlePhotosVideoDownloadUrl(String baseUrl) {
  if (baseUrl.contains('=')) {
    return baseUrl;
  }
  return '$baseUrl=dv';
}

Future<List<int>?> downloadGooglePhotosBytes({
  required http.Client client,
  required String downloadUrl,
  required String accessToken,
}) async {
  final res = await client.get(
    Uri.parse(downloadUrl),
    headers: {'Authorization': 'Bearer $accessToken'},
  );
  if (res.statusCode != 200) {
    return null;
  }
  return res.bodyBytes;
}
