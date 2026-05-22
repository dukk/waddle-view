import 'package:test/test.dart';
import 'package:waddle_shared/config/microsoft_graph_kv.dart';

void main() {
  test('microsoftGraphAccessTokenSecret scopes by account', () {
    expect(
      microsoftGraphAccessTokenSecret('work'),
      'provider:access_token:microsoft_graph:work',
    );
  });

  test('oneDriveMediaDeltaLinkKey tags root and nested paths', () {
    expect(oneDriveMediaDeltaLinkPathTag(''), '_root_');
    final nested = oneDriveMediaDeltaLinkPathTag('/Photos/2026');
    expect(nested, isNot('_root_'));
    expect(oneDriveMediaDeltaLinkKey('/Photos/2026'), 'delta_link.$nested');
  });

  test('kOneDriveMediaItemRowId is stable for drive item', () {
    final id = kOneDriveMediaItemRowId('work', 'item-42');
    expect(id, kOneDriveMediaItemRowId('work', 'item-42'));
    expect(id, isNot(equals(kOneDriveMediaItemRowId('work', 'item-43'))));
  });
}
