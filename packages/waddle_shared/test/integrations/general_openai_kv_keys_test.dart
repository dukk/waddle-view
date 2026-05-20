import 'package:flutter_test/flutter_test.dart';
import 'package:waddle_shared/integrations/general_openai_kv_keys.dart';
import 'package:waddle_shared/integrations/integration_kv_repository.dart';
import 'package:waddle_shared/integrations/integration_kv_types.dart';

void main() {
  group('generalOpenAi key builders', () {
    test('trim prompt id in key paths', () {
      expect(generalOpenAiPromptLatestKey('  demo  '), 'prompt.demo.latest');
      expect(
        generalOpenAiPromptHistoryKey('demo', 1700000000000),
        'prompt.demo.history.1700000000000',
      );
      expect(
        generalOpenAiPromptLastCollectKey('demo'),
        'prompt.demo.last_collect_ms',
      );
      expect(generalOpenAiPromptHistoryPrefix('demo'), 'prompt.demo.history.');
      expect(
        generalOpenAiPromptKeyPrefixForIntegration(),
        kGeneralOpenAiPromptKeyPrefix,
      );
    });
  });

  group('isGeneralOpenAiPromptLastCollectKey', () {
    test('matches poll gate keys only', () {
      expect(
        isGeneralOpenAiPromptLastCollectKey('prompt.foo.last_collect_ms'),
        isTrue,
      );
      expect(
        isGeneralOpenAiPromptLastCollectKey('prompt.foo.latest'),
        isFalse,
      );
      expect(
        isGeneralOpenAiPromptLastCollectKey('prompt.foo.history.1'),
        isFalse,
      );
      expect(isGeneralOpenAiPromptLastCollectKey('last_collect_ms'), isFalse);
    });
  });

  group('integrationKvTypeForKey', () {
    test('classifies general_openai prompt keys', () {
      expect(
        integrationKvTypeForKey('prompt.x.last_collect_ms'),
        kIntegrationKvTypeIntMs,
      );
      expect(
        integrationKvTypeForKey('prompt.x.latest'),
        kIntegrationKvTypeJson,
      );
      expect(
        integrationKvTypeForKey('prompt.x.history.42'),
        kIntegrationKvTypeJson,
      );
    });

    test('classifies built-in integration keys', () {
      expect(
        integrationKvTypeForKey(kIntegrationLastCollectKey),
        kIntegrationKvTypeIntMs,
      );
      expect(
        integrationKvTypeForKey('delta_link.folder1'),
        kIntegrationKvTypeDeltaLink,
      );
      expect(integrationKvTypeForKey('custom.key'), kIntegrationKvTypeString);
    });
  });
}
