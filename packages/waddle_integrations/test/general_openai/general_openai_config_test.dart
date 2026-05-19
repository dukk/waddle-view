import 'package:test/test.dart';
import 'package:waddle_integrations/general_openai/general_openai_config.dart';

void main() {
  test('parseMap reads prompts and defaults', () {
    const json = '''
{
  "defaultModel": "gpt-4o",
  "defaultRetentionDays": 7,
  "prompts": [
    {
      "id": "daily",
      "userPrompt": "Say hi",
      "pollSeconds": 60,
      "mcpServers": [
        {
          "serverLabel": "crm",
          "serverUrl": "https://example.com/mcp"
        }
      ]
    }
  ]
}
''';
    final cfg = GeneralOpenAiExtraConfig.parse(json);
    expect(cfg.defaultModel, 'gpt-4o');
    expect(cfg.defaultRetentionDays, 7);
    expect(cfg.prompts.length, 1);
    expect(cfg.prompts.first.id, 'daily');
    expect(cfg.prompts.first.mcpServers.length, 1);
    expect(cfg.modelFor(cfg.prompts.first), 'gpt-4o');
  });

  test('tryParse rejects invalid prompt', () {
    expect(
      GeneralOpenAiPromptConfig.tryParse({'id': '', 'userPrompt': 'x'}),
      isNull,
    );
  });
}
