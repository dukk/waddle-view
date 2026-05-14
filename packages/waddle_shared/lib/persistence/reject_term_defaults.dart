import 'tables.dart';

/// One row to seed into [RejectTerms] on first install / migration to v31.
class RejectTermSeed {
  const RejectTermSeed({
    required this.id,
    required this.term,
    required this.action,
  });

  /// Stable primary key (mirrors [term] but kept separate so operators can
  /// rename the term without changing the id; defaults seed ids as
  /// `default_<term>`).
  final String id;

  /// Lowercased single word stored in [RejectTerms.term].
  final String term;

  /// One of [kRejectTermActionCensor] or [kRejectTermActionBlock]; the
  /// repository validates this value before insert/update.
  final String action;
}

/// Default English curse-word list seeded on first install. Severe slurs and
/// the strongest expletives default to [kRejectTermActionBlock] so the curator
/// never schedules matching content; milder profanity defaults to
/// [kRejectTermActionCensor] so the underlying joke/news/trivia can still air
/// with the word masked. Operators may change either action via the REST API
/// or `waddlectl reject ...` at any time.
const List<RejectTermSeed> kDefaultRejectTermSeeds = <RejectTermSeed>[
  // Severe expletives default to block.
  RejectTermSeed(
    id: 'default_fuck',
    term: 'fuck',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_fucking',
    term: 'fucking',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_shit',
    term: 'shit',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_cunt',
    term: 'cunt',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_motherfucker',
    term: 'motherfucker',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_nigger',
    term: 'nigger',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_faggot',
    term: 'faggot',
    action: kRejectTermActionBlock,
  ),
  // Milder profanity defaults to censor so jokes/news with these words can
  // still appear with the word masked.
  RejectTermSeed(
    id: 'default_damn',
    term: 'damn',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_hell',
    term: 'hell',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_crap',
    term: 'crap',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_ass',
    term: 'ass',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_asshole',
    term: 'asshole',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_bitch',
    term: 'bitch',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_bastard',
    term: 'bastard',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_piss',
    term: 'piss',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_dick',
    term: 'dick',
    action: kRejectTermActionCensor,
  ),
];
