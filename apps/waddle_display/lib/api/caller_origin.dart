import 'package:shelf/shelf.dart';
import 'package:waddle_shared/auth/cors_origin_normalize.dart';

/// Reads caller origin from standard CORS [`Origin`] or [`Referer`] headers.
String? callerOriginFromRequest(Request request) {
  final origin = request.headers['origin'];
  if (origin != null && origin.trim().isNotEmpty) {
    return normalizeHttpOrigin(origin);
  }
  final referer = request.headers['referer'];
  if (referer != null && referer.trim().isNotEmpty) {
    return normalizeHttpOrigin(referer);
  }
  return null;
}
