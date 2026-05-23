import 'package:test/test.dart';
import 'package:waddle_integrations/tasks_trello/tasks_trello_provider_extra_config.dart';

void main() {
  test('parse boardIds and requestTimeoutMs', () {
    final cfg = TasksTrelloProviderExtraConfig.parse(
      '{"boardIds":["a","b"],"requestTimeoutMs":20000}',
    );
    expect(cfg.boardIds, ['a', 'b']);
    expect(cfg.requestTimeoutMs, 20000);
  });

  test('parse empty config defaults', () {
    final cfg = TasksTrelloProviderExtraConfig.parse(null);
    expect(cfg.boardIds, isEmpty);
    expect(cfg.requestTimeoutMs, kDefaultTasksTrelloRequestTimeoutMs);
  });
}
