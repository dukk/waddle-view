import 'package:test/test.dart';
import 'package:waddle_integrations/general_openai/openai_responses_client.dart';

void main() {
  test('extractResponsesOutputText from output_text', () {
    expect(
      extractResponsesOutputText({'output_text': 'hello'}),
      'hello',
    );
  });

  test('extractResponsesOutputText from message content', () {
    expect(
      extractResponsesOutputText({
        'output': [
          {
            'type': 'message',
            'content': [
              {'type': 'output_text', 'text': 'part1'},
              {'type': 'output_text', 'text': ' part2'},
            ],
          },
        ],
      }),
      'part1 part2',
    );
  });
}
