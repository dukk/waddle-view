import 'database.dart';
import 'tables.dart';

/// One row to seed into [RejectTerms] on first install.
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

/// Default English profanity, sexual, and derogatory term list. Severe slurs
/// and graphic sexual/violent terms default to [kRejectTermActionBlock]; milder
/// profanity and sexual slang default to [kRejectTermActionCensor]. Operators
/// may change either action via the REST API or `waddlectl reject ...` at any
/// time.
const List<RejectTermSeed> kDefaultRejectTermSeeds = <RejectTermSeed>[
  // Severe expletives (block).
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
    id: 'default_fucker',
    term: 'fucker',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_fucked',
    term: 'fucked',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_fucks',
    term: 'fucks',
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
    id: 'default_cocksucker',
    term: 'cocksucker',
    action: kRejectTermActionBlock,
  ),
  // Slurs (block).
  RejectTermSeed(
    id: 'default_nigger',
    term: 'nigger',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_nigga',
    term: 'nigga',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_faggot',
    term: 'faggot',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_fag',
    term: 'fag',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_chink',
    term: 'chink',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_gook',
    term: 'gook',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_spic',
    term: 'spic',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_kike',
    term: 'kike',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_wetback',
    term: 'wetback',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_coon',
    term: 'coon',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_beaner',
    term: 'beaner',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_dyke',
    term: 'dyke',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_tranny',
    term: 'tranny',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_shemale',
    term: 'shemale',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_retard',
    term: 'retard',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_retarded',
    term: 'retarded',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_raghead',
    term: 'raghead',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_towelhead',
    term: 'towelhead',
    action: kRejectTermActionBlock,
  ),
  // Sexual explicit / violent (block).
  RejectTermSeed(
    id: 'default_porn',
    term: 'porn',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_porno',
    term: 'porno',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_pornographic',
    term: 'pornographic',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_xxx',
    term: 'xxx',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_blowjob',
    term: 'blowjob',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_handjob',
    term: 'handjob',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_rimjob',
    term: 'rimjob',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_cum',
    term: 'cum',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_cumming',
    term: 'cumming',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_cumshot',
    term: 'cumshot',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_orgasm',
    term: 'orgasm',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_masturbate',
    term: 'masturbate',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_masturbation',
    term: 'masturbation',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_masturbating',
    term: 'masturbating',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_penis',
    term: 'penis',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_vagina',
    term: 'vagina',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_vulva',
    term: 'vulva',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_clitoris',
    term: 'clitoris',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_scrotum',
    term: 'scrotum',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_testicle',
    term: 'testicle',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_testicles',
    term: 'testicles',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_pussy',
    term: 'pussy',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_twat',
    term: 'twat',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_cock',
    term: 'cock',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_rape',
    term: 'rape',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_rapist',
    term: 'rapist',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_raping',
    term: 'raping',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_molest',
    term: 'molest',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_molestation',
    term: 'molestation',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_molester',
    term: 'molester',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_pedophile',
    term: 'pedophile',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_pedophilia',
    term: 'pedophilia',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_paedophile',
    term: 'paedophile',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_incest',
    term: 'incest',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_bestiality',
    term: 'bestiality',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_beastiality',
    term: 'beastiality',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_necrophilia',
    term: 'necrophilia',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_sodomy',
    term: 'sodomy',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_ejaculate',
    term: 'ejaculate',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_ejaculation',
    term: 'ejaculation',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_fellatio',
    term: 'fellatio',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_cunnilingus',
    term: 'cunnilingus',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_dildo',
    term: 'dildo',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_vibrator',
    term: 'vibrator',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_gangbang',
    term: 'gangbang',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_bukkake',
    term: 'bukkake',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_orgy',
    term: 'orgy',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_hentai',
    term: 'hentai',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_prostitute',
    term: 'prostitute',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_prostitution',
    term: 'prostitution',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_hooker',
    term: 'hooker',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_erection',
    term: 'erection',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_horny',
    term: 'horny',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_threesome',
    term: 'threesome',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_anal',
    term: 'anal',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_slut',
    term: 'slut',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_whore',
    term: 'whore',
    action: kRejectTermActionBlock,
  ),
  RejectTermSeed(
    id: 'default_skank',
    term: 'skank',
    action: kRejectTermActionBlock,
  ),
  // Milder profanity (censor).
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
    id: 'default_bitches',
    term: 'bitches',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_bitchy',
    term: 'bitchy',
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
  RejectTermSeed(
    id: 'default_dicks',
    term: 'dicks',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_dickhead',
    term: 'dickhead',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_dickwad',
    term: 'dickwad',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_bullshit',
    term: 'bullshit',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_shitty',
    term: 'shitty',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_shits',
    term: 'shits',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_shitting',
    term: 'shitting',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_horseshit',
    term: 'horseshit',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_jackass',
    term: 'jackass',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_dumbass',
    term: 'dumbass',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_badass',
    term: 'badass',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_prick',
    term: 'prick',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_pricks',
    term: 'pricks',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_wanker',
    term: 'wanker',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_wanking',
    term: 'wanking',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_wank',
    term: 'wank',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_bollocks',
    term: 'bollocks',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_bugger',
    term: 'bugger',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_suck',
    term: 'suck',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_sucks',
    term: 'sucks',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_sucked',
    term: 'sucked',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_screwed',
    term: 'screwed',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_screw',
    term: 'screw',
    action: kRejectTermActionCensor,
  ),
  // Sexual slang (censor).
  RejectTermSeed(
    id: 'default_sex',
    term: 'sex',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_sexual',
    term: 'sexual',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_sexuality',
    term: 'sexuality',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_intercourse',
    term: 'intercourse',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_nude',
    term: 'nude',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_naked',
    term: 'naked',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_nudity',
    term: 'nudity',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_tits',
    term: 'tits',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_boobs',
    term: 'boobs',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_boob',
    term: 'boob',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_boobies',
    term: 'boobies',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_boner',
    term: 'boner',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_balls',
    term: 'balls',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_stripper',
    term: 'stripper',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_stripping',
    term: 'stripping',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_striptease',
    term: 'striptease',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_lapdance',
    term: 'lapdance',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_foreplay',
    term: 'foreplay',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_fetish',
    term: 'fetish',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_kinky',
    term: 'kinky',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_erotic',
    term: 'erotic',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_orgasmic',
    term: 'orgasmic',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_semen',
    term: 'semen',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_sperm',
    term: 'sperm',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_condom',
    term: 'condom',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_viagra',
    term: 'viagra',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_cialis',
    term: 'cialis',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_hoe',
    term: 'hoe',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_hoes',
    term: 'hoes',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_slutty',
    term: 'slutty',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_nsfw',
    term: 'nsfw',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_cameltoe',
    term: 'cameltoe',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_deepthroat',
    term: 'deepthroat',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_creampie',
    term: 'creampie',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_milf',
    term: 'milf',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_dilf',
    term: 'dilf',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_bdsm',
    term: 'bdsm',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_dominatrix',
    term: 'dominatrix',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_bondage',
    term: 'bondage',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_lingerie',
    term: 'lingerie',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_playboy',
    term: 'playboy',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_sexting',
    term: 'sexting',
    action: kRejectTermActionCensor,
  ),
  RejectTermSeed(
    id: 'default_hookup',
    term: 'hookup',
    action: kRejectTermActionCensor,
  ),
];

/// Idempotent inserts for [RejectTerms] default rows (`default_*` ids only).
Future<void> ensureDefaultRejectTerms(AppDatabase db) async {
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  for (final entry in kDefaultRejectTermSeeds) {
    final existing = await (db.select(db.rejectTerms)
          ..where((t) => t.id.equals(entry.id)))
        .getSingleOrNull();
    if (existing != null) {
      continue;
    }
    await db.into(db.rejectTerms).insert(
          RejectTermsCompanion.insert(
            id: entry.id,
            term: entry.term,
            action: entry.action,
            createdAtMs: nowMs,
            updatedAtMs: nowMs,
          ),
        );
  }
}
