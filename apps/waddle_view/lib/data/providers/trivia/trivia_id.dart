import 'dart:convert';

import 'package:crypto/crypto.dart';

String triviaStableId(
  String categoryId,
  String question,
  String optionA,
  String optionB,
  String optionC,
  String optionD,
  String correctOption,
) {
  final h = sha256.convert(
    utf8.encode(
      '$categoryId\x00$question\x00$optionA\x00$optionB\x00'
      '$optionC\x00$optionD\x00$correctOption',
    ),
  );
  return h.toString();
}
