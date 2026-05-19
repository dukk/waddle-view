import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:waddle_shared/config/google_kv.dart';

/// One item returned by Google Photos Picker [listMediaItems].
class GooglePhotosPickedMediaItem {
  const GooglePhotosPickedMediaItem({
    required this.id,
    required this.mimeType,
    required this.baseUrl,
    this.filename = '',
    this.type = '',
    this.width,
    this.height,
    this.videoProcessingStatus,
  });

  final String id;
  final String mimeType;
  final String baseUrl;
  final String filename;
  final String type;
  final int? width;
  final int? height;
  final String? videoProcessingStatus;

  bool get isPhoto =>
      type == 'PHOTO' || mimeType.toLowerCase().startsWith('image/');

  bool get isVideo =>
      type == 'VIDEO' || mimeType.toLowerCase().startsWith('video/');

  static GooglePhotosPickedMediaItem? fromJson(Map<String, dynamic> m) {
    final id = m['id'];
    if (id is! String || id.isEmpty) {
      return null;
    }
    final mediaFile = m['mediaFile'];
    if (mediaFile is! Map<String, dynamic>) {
      return null;
    }
    final baseUrl = mediaFile['baseUrl'];
    final mimeType = mediaFile['mimeType'];
    if (baseUrl is! String ||
        baseUrl.isEmpty ||
        mimeType is! String ||
        mimeType.isEmpty) {
      return null;
    }
    final meta = mediaFile['mediaFileMetadata'];
    int? width;
    int? height;
    String? videoStatus;
    if (meta is Map<String, dynamic>) {
      final w = meta['width'];
      final h = meta['height'];
      if (w is int) {
        width = w;
      } else if (w is num) {
        width = w.toInt();
      }
      if (h is int) {
        height = h;
      } else if (h is num) {
        height = h.toInt();
      }
      final videoMeta = meta['videoMetadata'];
      if (videoMeta is Map<String, dynamic>) {
        final st = videoMeta['processingStatus'];
        if (st is String) {
          videoStatus = st;
        }
      }
    }
    final type = m['type'];
    final filename = mediaFile['filename'];
    return GooglePhotosPickedMediaItem(
      id: id,
      mimeType: mimeType,
      baseUrl: baseUrl,
      filename: filename is String ? filename : '',
      type: type is String ? type : '',
      width: width,
      height: height,
      videoProcessingStatus: videoStatus,
    );
  }
}

class GooglePhotosPickerSession {
  const GooglePhotosPickerSession({
    required this.id,
    required this.pickerUri,
    this.mediaItemsSet = false,
    this.recommendedPollIntervalMs,
    this.recommendedTimeoutMs,
  });

  final String id;
  final String pickerUri;
  final bool mediaItemsSet;
  final int? recommendedPollIntervalMs;
  final int? recommendedTimeoutMs;

  static GooglePhotosPickerSession? fromJson(Map<String, dynamic> m) {
    final id = m['id'];
    final pickerUri = m['pickerUri'];
    if (id is! String ||
        id.isEmpty ||
        pickerUri is! String ||
        pickerUri.isEmpty) {
      return null;
    }
    final poll = m['pollingConfig'];
    int? pollMs;
    int? timeoutMs;
    if (poll is Map<String, dynamic>) {
      final interval = poll['pollInterval'];
      final timeout = poll['timeoutIn'];
      if (interval is String) {
        pollMs = _durationMs(interval);
      }
      if (timeout is String) {
        timeoutMs = _durationMs(timeout);
      }
    }
    return GooglePhotosPickerSession(
      id: id,
      pickerUri: pickerUri,
      mediaItemsSet: m['mediaItemsSet'] == true,
      recommendedPollIntervalMs: pollMs,
      recommendedTimeoutMs: timeoutMs,
    );
  }
}

int? _durationMs(String protoDuration) {
  final t = protoDuration.trim();
  if (!t.endsWith('s')) {
    return null;
  }
  final sec = double.tryParse(t.substring(0, t.length - 1));
  if (sec == null) {
    return null;
  }
  return (sec * 1000).round();
}

/// Client for Google Photos Picker REST API.
class GooglePhotosPickerApi {
  GooglePhotosPickerApi({
    http.Client? httpClient,
    String baseUrl = kGooglePhotosPickerApiBaseUrl,
  })  : _http = httpClient ?? http.Client(),
        _base = baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl;

  final http.Client _http;
  final String _base;

  Future<GooglePhotosPickerSession> createSession({
    required String accessToken,
    String? requestId,
  }) async {
    final query = <String, String>{};
    if (requestId != null && requestId.isNotEmpty) {
      query['requestId'] = requestId;
    }
    final uri = Uri.parse('$_base/sessions').replace(queryParameters: query);
    final res = await _http.post(
      uri,
      headers: _authHeaders(accessToken),
      body: '{}',
    );
    return _parseSessionResponse(res);
  }

  Future<GooglePhotosPickerSession> getSession({
    required String accessToken,
    required String sessionId,
  }) async {
    final uri = Uri.parse('$_base/sessions/$sessionId');
    final res = await _http.get(uri, headers: _authHeaders(accessToken));
    return _parseSessionResponse(res);
  }

  Future<void> deleteSession({
    required String accessToken,
    required String sessionId,
  }) async {
    final uri = Uri.parse('$_base/sessions/$sessionId');
    await _http.delete(uri, headers: _authHeaders(accessToken));
  }

  Future<({List<GooglePhotosPickedMediaItem> items, String? nextPageToken})>
      listMediaItems({
    required String accessToken,
    required String sessionId,
    int pageSize = 100,
    String? pageToken,
  }) async {
    final query = <String, String>{
      'sessionId': sessionId,
      'pageSize': '$pageSize',
    };
    if (pageToken != null && pageToken.isNotEmpty) {
      query['pageToken'] = pageToken;
    }
    final uri = Uri.parse('$_base/mediaItems').replace(queryParameters: query);
    final res = await _http.get(uri, headers: _authHeaders(accessToken));
    if (res.statusCode != 200) {
      throw GooglePhotosPickerApiException(res.statusCode, res.body);
    }
    final m = jsonDecode(res.body) as Map<String, dynamic>;
    final items = <GooglePhotosPickedMediaItem>[];
    final raw = m['mediaItems'];
    if (raw is List<dynamic>) {
      for (final e in raw) {
        if (e is Map<String, dynamic>) {
          final item = GooglePhotosPickedMediaItem.fromJson(e);
          if (item != null) {
            items.add(item);
          }
        }
      }
    }
    final next = m['nextPageToken'];
    return (
      items: items,
      nextPageToken: next is String && next.isNotEmpty ? next : null,
    );
  }

  Future<List<GooglePhotosPickedMediaItem>> listAllMediaItems({
    required String accessToken,
    required String sessionId,
  }) async {
    final all = <GooglePhotosPickedMediaItem>[];
    String? token;
    do {
      final page = await listMediaItems(
        accessToken: accessToken,
        sessionId: sessionId,
        pageToken: token,
      );
      all.addAll(page.items);
      token = page.nextPageToken;
    } while (token != null);
    return all;
  }

  GooglePhotosPickerSession _parseSessionResponse(http.Response res) {
    if (res.statusCode != 200) {
      throw GooglePhotosPickerApiException(res.statusCode, res.body);
    }
    final m = jsonDecode(res.body) as Map<String, dynamic>;
    final session = GooglePhotosPickerSession.fromJson(m);
    if (session == null) {
      throw GooglePhotosPickerApiException(
        res.statusCode,
        'invalid_session_response',
      );
    }
    return session;
  }

  Map<String, String> _authHeaders(String accessToken) => {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      };
}

class GooglePhotosPickerApiException implements Exception {
  GooglePhotosPickerApiException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'GooglePhotosPickerApiException($statusCode)';
}
