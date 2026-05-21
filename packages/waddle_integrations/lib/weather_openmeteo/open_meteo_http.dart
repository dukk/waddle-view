import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:waddle_shared/collect/collect_diagnostics.dart';
import 'package:waddle_shared/net/http_debug_uri.dart';

/// GET [uri]; returns null on transport failure (logged via [diagnostics]).
Future<http.Response?> openMeteoSafeGet(
  http.Client client,
  Uri uri, {
  required CollectDiagnostics diagnostics,
  required String logLabel,
  String? locationId,
}) async {
  final loc = locationId == null ? '' : ' location=$locationId';
  try {
    final res = await client.get(uri);
    diagnostics.provider(
      '$logLabel ok$loc status=${res.statusCode} bytes=${res.bodyBytes.length} '
      '${safeHttpUriForLog(uri)}',
    );
    return res;
  } on http.ClientException catch (e, st) {
    diagnostics.providerFail('$logLabel request failed$loc', e, st);
    return null;
  } on SocketException catch (e, st) {
    diagnostics.providerFail('$logLabel socket failed$loc', e, st);
    return null;
  } on Object catch (e, st) {
    diagnostics.providerFail('$logLabel unexpected error$loc', e, st);
    return null;
  }
}

/// Strips trailing slashes from integration [baseUrl].
String normalizeOpenMeteoBaseUrl(String? baseUrl, String defaultBase) {
  final raw = (baseUrl != null && baseUrl.trim().isNotEmpty)
      ? baseUrl.trim()
      : defaultBase;
  return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
}
