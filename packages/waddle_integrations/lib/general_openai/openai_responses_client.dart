import 'dart:convert';

import 'package:http/http.dart' as http;

/// Result of a successful OpenAI Responses API call.
class OpenAiResponsesResult {
  const OpenAiResponsesResult({required this.outputText});

  final String outputText;
}

/// POST [baseUrl]/responses and extract assistant text.
class OpenAiResponsesClient {
  OpenAiResponsesClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;

  Future<OpenAiResponsesResult?> createResponse({
    required Uri uri,
    required String bearerToken,
    required Map<String, Object?> body,
  }) async {
    final res = await _http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $bearerToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    if (res.statusCode != 200) {
      return null;
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    final text = extractResponsesOutputText(decoded);
    if (text == null || text.isEmpty) {
      return null;
    }
    return OpenAiResponsesResult(outputText: text);
  }
}

/// Parses primary text from a Responses API JSON body (tolerant of shape changes).
String? extractResponsesOutputText(Map<String, dynamic> decoded) {
  final direct = decoded['output_text'];
  if (direct is String && direct.trim().isNotEmpty) {
    return direct.trim();
  }
  final output = decoded['output'];
  if (output is! List<dynamic>) {
    return null;
  }
  final buffer = StringBuffer();
  for (final item in output) {
    if (item is! Map<String, dynamic>) {
      continue;
    }
    final type = item['type'];
    if (type == 'message') {
      final content = item['content'];
      if (content is List<dynamic>) {
        for (final part in content) {
          if (part is Map<String, dynamic>) {
            final partType = part['type'];
            final text = part['text'];
            if ((partType == 'output_text' || partType == 'text') &&
                text is String &&
                text.isNotEmpty) {
              buffer.write(text);
            }
          }
        }
      }
      continue;
    }
    if (type == 'output_text') {
      final text = item['text'];
      if (text is String && text.isNotEmpty) {
        buffer.write(text);
      }
    }
  }
  final joined = buffer.toString().trim();
  return joined.isEmpty ? null : joined;
}
