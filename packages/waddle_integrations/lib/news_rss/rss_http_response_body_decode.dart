import 'dart:convert';

import 'package:http/http.dart' as http;

/// Decodes an RSS/Atom HTTP response body without mis-treating UTF-8 as Latin-1.
///
/// [http.Response.body] defaults to [latin1] when `Content-Type` omits
/// `charset` (except for `application/json`). UTF-8 feeds then show mojibake
/// such as "â" for typographic apostrophes (U+2019) after C1 controls are
/// stripped downstream.
String decodeRssHttpResponseBody(http.Response res) {
  final bytes = res.bodyBytes;
  final headerCharset = _charsetFromContentType(res.headers['content-type']);
  if (headerCharset != null) {
    final enc = Encoding.getByName(headerCharset);
    if (enc != null) {
      return enc.decode(bytes);
    }
  }

  var offset = 0;
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    offset = 3;
  }

  final declName =
      _encodingNameFromXmlDeclaration(bytes, startOffset: offset);
  if (declName != null) {
    final enc = Encoding.getByName(declName);
    if (enc != null) {
      return enc.decode(offset == 0 ? bytes : bytes.sublist(offset));
    }
  }

  final payload = offset == 0 ? bytes : bytes.sublist(offset);
  try {
    return utf8.decode(payload);
  } on FormatException {
    return latin1.decode(payload);
  }
}

String? _charsetFromContentType(String? raw) {
  if (raw == null || raw.isEmpty) {
    return null;
  }
  final m = RegExp(
    r'''charset\s*=\s*["']?([^"'\s;]+)["']?''',
    caseSensitive: false,
  ).firstMatch(raw);
  final name = m?.group(1)?.trim();
  if (name == null || name.isEmpty) {
    return null;
  }
  return name;
}

String? _encodingNameFromXmlDeclaration(
  List<int> bytes, {
  required int startOffset,
}) {
  final n = bytes.length - startOffset;
  if (n < 2) {
    return null;
  }
  final take = n < 512 ? n : 512;
  final slice = bytes.sublist(startOffset, startOffset + take);
  final header = latin1.decode(slice);
  final m = RegExp(
    r'''encoding\s*=\s*["']([^"']+)["']''',
    caseSensitive: false,
  ).firstMatch(header);
  final name = m?.group(1)?.trim();
  if (name == null || name.isEmpty) {
    return null;
  }
  return name;
}
