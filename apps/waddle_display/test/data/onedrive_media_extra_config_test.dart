import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_display/data/providers/onedrive_media/onedrive_media_extra_config.dart';

void main() {
  test('defaults when null or empty', () {
    final c = OneDriveMediaExtraConfig.parse(null);
    expect(c.accounts, isEmpty);
    expect(c.globalPerPollLimit, 50);
  });

  test('parse accounts, sources, and globalPerPollLimit', () {
    final c = OneDriveMediaExtraConfig.parse(
      '{"accounts":[{"graphAccountKey":"p","sources":['
      '{"path":"/Pictures/X","kind":"photo","category":"x","maxFiles":10,"perPollLimit":2},'
      '{"folder":"/Videos/Y","kind":"video","category":"y","maxFiles":3}'
      ']}],"globalPerPollLimit":40}',
    );
    expect(c.globalPerPollLimit, 40);
    expect(c.accounts.length, 1);
    expect(c.accounts.single.graphAccountKey, 'p');
    expect(c.accounts.single.sources.length, 2);
    expect(c.accounts.single.sources.first.path, '/Pictures/X');
    expect(c.accounts.single.sources.first.kind, 'photo');
    expect(c.accounts.single.sources.first.category, 'x');
    expect(c.accounts.single.sources.first.maxFiles, 10);
    expect(c.accounts.single.sources.first.perPollLimit, 2);
    expect(c.accounts.single.sources.first.effectivePerPollLimit, 2);
    expect(c.accounts.single.sources.last.kind, 'video');
    expect(c.accounts.single.sources.last.effectivePerPollLimit, 3);
  });

  test('invalid kind drops source', () {
    final c = OneDriveMediaExtraConfig.parse(
      '{"accounts":[{"graphAccountKey":"a","sources":['
      '{"path":"/p","kind":"audio","category":"c"}'
      ']}]}',
    );
    expect(c.accounts.single.sources, isEmpty);
  });

  test('kind both parses', () {
    final c = OneDriveMediaExtraConfig.parse(
      '{"accounts":[{"graphAccountKey":"a","sources":['
      '{"path":"/mix","kind":"both","category":"c","maxFiles":5}'
      ']}]}',
    );
    expect(c.accounts.single.sources.single.kind, 'both');
  });

  test('empty path is allowed (drive root)', () {
    final c = OneDriveMediaExtraConfig.parse(
      '{"accounts":[{"graphAccountKey":"a","sources":['
      '{"path":"","kind":"photo","category":"c","maxFiles":5}'
      ']}]}',
    );
    expect(c.accounts.single.sources.single.path, '');
  });

  test('missing category drops source', () {
    final c = OneDriveMediaExtraConfig.parse(
      '{"accounts":[{"graphAccountKey":"a","sources":['
      '{"path":"/p","kind":"photo"}'
      ']}]}',
    );
    expect(c.accounts.single.sources, isEmpty);
  });
}
