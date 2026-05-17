import 'package:waddle_shared/auth/adoption_challenge_format.dart';

/// Parses the challenge from a display adoption alert body (see [AdoptionRepository.startRequest]).
String adoptionChallengeFromAlertBody(String body) {
  const prefix = 'Challenge code: ';
  final idx = body.lastIndexOf(prefix);
  if (idx < 0) {
    throw StateError('adoption alert missing challenge line');
  }
  return normalizeAdoptionChallengeCode(
    body.substring(idx + prefix.length).trim(),
  );
}
