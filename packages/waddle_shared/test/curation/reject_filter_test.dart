import 'package:test/test.dart';
import 'package:waddle_shared/curation/reject_filter.dart';
import 'package:waddle_shared/persistence/tables.dart';

RejectFilterTerm _censor(String term) =>
    RejectFilterTerm(term: term, action: kRejectTermActionCensor);

RejectFilterTerm _block(String term) =>
    RejectFilterTerm(term: term, action: kRejectTermActionBlock);

void main() {
  group('censorText', () {
    test('respects word boundaries (no substring matches)', () {
      final out = censorText(
        'The assassin walked past.',
        const <RejectFilterTerm>[],
        CensorFormat.asterisksFull,
      );
      expect(out, 'The assassin walked past.');

      final outWithAss = censorText(
        'The assassin walked past an ass.',
        [_censor('ass')],
        CensorFormat.asterisksFull,
      );
      expect(outWithAss, 'The assassin walked past an ***.');
    });

    test('asterisks_full masks each character of the matched word', () {
      final out = censorText(
        'Holy damn what a day',
        [_censor('damn')],
        CensorFormat.asterisksFull,
      );
      expect(out, 'Holy **** what a day');
    });

    test('asterisks_fixed always replaces with four asterisks', () {
      final out = censorText(
        'damn motherfucker stop',
        [_censor('damn'), _censor('motherfucker')],
        CensorFormat.asterisksFixed,
      );
      expect(out, '**** **** stop');
    });

    test('first_last keeps first and last chars when length >= 3', () {
      final out = censorText(
        'damn what the heck',
        [_censor('damn'), _censor('heck')],
        CensorFormat.firstLast,
      );
      expect(out, 'd**n what the h**k');
    });

    test('first_last falls back to all asterisks for short words', () {
      final out = censorText(
        'oh no',
        [_censor('oh'), _censor('no')],
        CensorFormat.firstLast,
      );
      expect(out, '** **');
    });

    test('bracketed_token replaces with [censored]', () {
      final out = censorText(
        'damn it all',
        [_censor('damn')],
        CensorFormat.bracketedToken,
      );
      expect(out, '[censored] it all');
    });

    test('matches case-insensitively', () {
      final out = censorText(
        'DAMN Damn damn DaMn',
        [_censor('damn')],
        CensorFormat.asterisksFull,
      );
      expect(out, '**** **** **** ****');
    });

    test('block-only terms are skipped by censorText (display is for censor)',
        () {
      final out = censorText(
        'this is shit damn',
        [_block('shit'), _censor('damn')],
        CensorFormat.asterisksFull,
      );
      expect(out, 'this is shit ****');
    });

    test('regex metacharacters in terms are escaped', () {
      final out = censorText(
        'a.b+c d.e',
        [_censor('a.b+c')],
        CensorFormat.bracketedToken,
      );
      expect(out, '[censored] d.e');
    });

    test('empty input returns empty', () {
      expect(censorText('', [_censor('damn')], CensorFormat.asterisksFull),
          '');
    });
  });

  group('hasBlockMatch', () {
    test('returns true when any block term matches', () {
      expect(
        hasBlockMatch(
          'oh hell, what a shitstorm',
          [_block('shit')],
        ),
        isFalse,
        reason: 'shit only matches when whole-word; "shitstorm" should not',
      );
      expect(
        hasBlockMatch(
          'this is shit',
          [_block('shit')],
        ),
        isTrue,
      );
    });

    test('censor-action terms do not trigger block', () {
      expect(
        hasBlockMatch(
          'damn that was close',
          [_censor('damn')],
        ),
        isFalse,
      );
    });

    test('matches case-insensitively', () {
      expect(
        hasBlockMatch(
          'Holy SHIT',
          [_block('shit')],
        ),
        isTrue,
      );
    });

    test('empty body or empty list returns false', () {
      expect(hasBlockMatch('', [_block('damn')]), isFalse);
      expect(hasBlockMatch('damn', const []), isFalse);
    });

    test('null-safe variants treat null as empty', () {
      expect(hasBlockMatchAny([null, '   '], [_block('damn')]), isFalse);
      expect(
        hasBlockMatchAny(['ok', 'damn it all'], [_block('damn')]),
        isTrue,
      );
    });
  });

  group('normalizeForUrlMatch', () {
    test('lowercases and treats separators as spaces', () {
      expect(
        normalizeForUrlMatch(
          'https://Example.com/photos/Cool-Sunset_Beach.jpg?ref=Foo&size=Large',
        ),
        contains('cool sunset beach jpg'),
      );
    });

    test('collapses runs of separators', () {
      expect(
        normalizeForUrlMatch('Foo___---bar.._baz'),
        'foo bar baz',
      );
    });

    test('null/empty url returns empty string', () {
      expect(normalizeForUrlMatch(null), '');
      expect(normalizeForUrlMatch('   '), '');
    });
  });

  group('mediaMatchesAnyTerm', () {
    test('matches term in photographer name', () {
      expect(
        mediaMatchesAnyTerm(
          photographer: 'Jane Damn-Smith',
          altText: 'A lovely scene',
          urls: const ['https://example.com/p/1'],
          terms: [_censor('damn')],
        ),
        isTrue,
        reason: 'photographer name normalization respects - separator',
      );
    });

    test('matches term in alt text', () {
      expect(
        mediaMatchesAnyTerm(
          photographer: 'Joe',
          altText: 'sunset over the bitch creek',
          urls: const [],
          terms: [_block('bitch')],
        ),
        isTrue,
      );
    });

    test('matches term in url after normalization (- and _ as spaces)', () {
      expect(
        mediaMatchesAnyTerm(
          photographer: 'Anonymous',
          altText: 'safe alt',
          urls: const [
            'https://images.example/pics/holy-damn-vista_2024.jpg',
          ],
          terms: [_censor('damn')],
        ),
        isTrue,
      );
    });

    test('media match treats censor and block terms identically', () {
      // For media, both actions cause a block (images cannot be censored).
      expect(
        mediaMatchesAnyTerm(
          photographer: 'A',
          altText: 'B',
          urls: const ['https://x/y/shit_show.jpg'],
          terms: [_censor('shit')],
        ),
        isTrue,
      );
    });

    test('returns false when no field matches', () {
      expect(
        mediaMatchesAnyTerm(
          photographer: 'Alice',
          altText: 'fluffy clouds',
          urls: const ['https://example.com/pics/clouds.jpg'],
          terms: [_block('damn'), _censor('shit')],
        ),
        isFalse,
      );
    });

    test('handles null fields gracefully', () {
      expect(
        mediaMatchesAnyTerm(
          photographer: null,
          altText: null,
          urls: const [null, ''],
          terms: [_block('damn')],
        ),
        isFalse,
      );
    });

    test('empty term list never matches', () {
      expect(
        mediaMatchesAnyTerm(
          photographer: 'damn',
          altText: 'damn',
          urls: const ['damn.jpg'],
          terms: const [],
        ),
        isFalse,
      );
    });
  });

  group('parseCensorFormat', () {
    test('maps known KV values', () {
      expect(parseCensorFormatKv(kRejectCensorFormatAsterisksFull),
          CensorFormat.asterisksFull);
      expect(parseCensorFormatKv(kRejectCensorFormatAsterisksFixed),
          CensorFormat.asterisksFixed);
      expect(parseCensorFormatKv(kRejectCensorFormatFirstLast),
          CensorFormat.firstLast);
      expect(parseCensorFormatKv(kRejectCensorFormatBracketedToken),
          CensorFormat.bracketedToken);
    });

    test('falls back to asterisks_full for unknown/empty', () {
      expect(parseCensorFormatKv(null), CensorFormat.asterisksFull);
      expect(parseCensorFormatKv(''), CensorFormat.asterisksFull);
      expect(parseCensorFormatKv('bogus'), CensorFormat.asterisksFull);
    });
  });
}
