import 'dart:convert';

import 'package:crypto/crypto.dart';

const String kTriviaQuestionTypeMultipleChoice = 'multiple_choice';
const String kTriviaQuestionTypeTrueFalse = 'true_false';

String triviaStableId(
  String categoryId,
  String question,
  String optionA,
  String optionB,
  String? optionC,
  String? optionD,
  String correctOption,
  String questionType = kTriviaQuestionTypeMultipleChoice,
) {
  // Keep the legacy hash payload for multiple-choice rows so existing IDs stay stable.
  if (questionType == kTriviaQuestionTypeMultipleChoice) {
    final c = optionC ?? '';
    final d = optionD ?? '';
    final h = sha256.convert(
      utf8.encode(
        '$categoryId\x00$question\x00$optionA\x00$optionB\x00'
        '$c\x00$d\x00$correctOption',
      ),
    );
    return h.toString();
  }
  final h = sha256.convert(
    utf8.encode(
      '$categoryId\x00$question\x00$optionA\x00$optionB\x00'
      '${optionC ?? ''}\x00${optionD ?? ''}\x00$correctOption\x00$questionType',
    ),
  );
  return h.toString();
}
