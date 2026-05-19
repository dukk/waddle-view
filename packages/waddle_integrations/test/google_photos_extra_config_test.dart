import 'package:test/test.dart';
import 'package:waddle_integrations/google_photos/google_photos_extra_config.dart';

void main() {
  test('parse accounts and sources', () {
    final extra = GooglePhotosExtraConfig.parse('''
{
  "globalPerPollLimit": 25,
  "accounts": [
    {
      "googleAccountKey": "family",
      "sources": [
        {
          "sourceId": "vacation",
          "albumLabel": "Vacation",
          "albumSearchHint": "Vacation 2025",
          "category": "family_media",
          "maxFiles": 100,
          "perPollLimit": 5,
          "mediaItemIds": ["id1", "id2"],
          "pickerSessionId": "sess-abc",
          "lastPickedAtMs": 1716000000000
        }
      ]
    }
  ]
}
''');
    expect(extra.globalPerPollLimit, 25);
    expect(extra.accounts, hasLength(1));
    final account = extra.accounts.single;
    expect(account.googleAccountKey, 'family');
    expect(account.sources, hasLength(1));
    final source = account.sources.single;
    expect(source.sourceId, 'vacation');
    expect(source.albumLabel, 'Vacation');
    expect(source.albumSearchHint, 'Vacation 2025');
    expect(source.category, 'family_media');
    expect(source.maxFiles, 100);
    expect(source.perPollLimit, 5);
    expect(source.effectivePerPollLimit, 5);
    expect(source.mediaItemIds, ['id1', 'id2']);
    expect(source.pickerSessionId, 'sess-abc');
    expect(source.lastPickedAtMs, 1716000000000);
  });

  test('parse empty config', () {
    final extra = GooglePhotosExtraConfig.parse(null);
    expect(extra.accounts, isEmpty);
    expect(extra.globalPerPollLimit, 50);
  });
}
