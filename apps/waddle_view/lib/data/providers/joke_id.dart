import 'dart:convert';

import 'package:crypto/crypto.dart';

String jokeStableId(String categoryId, String setup, String punchline) {
  final h = sha256.convert(utf8.encode('$categoryId\x00$setup\x00$punchline'));
  return h.toString();
}
