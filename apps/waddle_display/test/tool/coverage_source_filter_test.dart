import 'package:flutter_test/flutter_test.dart';

import '../../tool/coverage_source_filter.dart';

void main() {
  group('includeCoverageSourceFile', () {
    test('includes display lib paths from display lcov', () {
      expect(
        includeCoverageSourceFile(
          'lib/api/foo.dart',
          lcovPath: 'coverage/lcov.info',
        ),
        isTrue,
      );
      expect(
        includeCoverageSourceFile(
          '/home/runner/work/waddle-view/apps/waddle_display/lib/api/foo.dart',
          lcovPath: 'apps/waddle_display/coverage/lcov.info',
        ),
        isTrue,
      );
    });

    test('includes shared and plugin_sdk paths from their lcov files', () {
      expect(
        includeCoverageSourceFile(
          'packages/waddle_shared/lib/persistence/database.dart',
          lcovPath: 'packages/waddle_shared/coverage/lcov.info',
        ),
        isTrue,
      );
      expect(
        includeCoverageSourceFile(
          'lib/plugin_sdk.dart',
          lcovPath: 'packages/waddle_plugin_sdk/coverage/lcov.info',
        ),
        isTrue,
      );
    });

    test('never includes waddle_integrations paths', () {
      const integrationsLcov =
          'packages/waddle_integrations/coverage/lcov.info';
      expect(
        includeCoverageSourceFile(
          'packages/waddle_integrations/lib/joke_openai/joke_data_provider.dart',
          lcovPath: integrationsLcov,
        ),
        isFalse,
      );
      expect(
        includeCoverageSourceFile(
          'lib/joke_openai/joke_data_provider.dart',
          lcovPath: integrationsLcov,
        ),
        isFalse,
      );
    });

    test('excludes plugin_example and generated or excluded files', () {
      expect(
        includeCoverageSourceFile(
          'packages/waddle_plugin_example/lib/example.dart',
          lcovPath: 'coverage/lcov.info',
        ),
        isFalse,
      );
      expect(
        includeCoverageSourceFile(
          'lib/persistence/tables.g.dart',
          lcovPath: 'coverage/lcov.info',
        ),
        isFalse,
      );
      expect(
        includeCoverageSourceFile(
          'lib/main.dart',
          lcovPath: 'coverage/lcov.info',
        ),
        isFalse,
      );
      expect(
        includeCoverageSourceFile(
          'lib/display/screen_rotator.dart',
          lcovPath: 'coverage/lcov.info',
        ),
        isFalse,
      );
    });
  });
}
