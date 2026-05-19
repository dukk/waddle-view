import 'package:shelf/shelf.dart';

/// True when list GETs should include `config_json_schema` and `example_config_json`.
bool includeConfigSchemaFromRequest(Request req) {
  final v = req.url.queryParameters['include_config_schema'];
  if (v == null) {
    return false;
  }
  final lower = v.toLowerCase();
  return lower == 'true' || lower == '1';
}
