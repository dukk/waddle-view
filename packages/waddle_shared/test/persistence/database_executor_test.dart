import 'package:flutter_test/flutter_test.dart';
import 'package:postgres/postgres.dart' as pg;
import 'package:waddle_shared/persistence/database_executor.dart';

void main() {
  group('postgresSslModeFromUrl', () {
    test('defaults to disable for localhost without sslmode', () {
      expect(
        postgresSslModeFromUrl(
          'postgres://waddle:waddle@localhost:5432/waddle_display_test',
        ),
        pg.SslMode.disable,
      );
    });

    test('defaults to disable for 127.0.0.1 without sslmode', () {
      expect(
        postgresSslModeFromUrl(
          'postgres://waddle:waddle@127.0.0.1:5432/waddle_display_test',
        ),
        pg.SslMode.disable,
      );
    });

    test('defaults to require for remote hosts without sslmode', () {
      expect(
        postgresSslModeFromUrl(
          'postgres://waddle:waddle@db.example.com:5432/waddle_display',
        ),
        pg.SslMode.require,
      );
    });

    test('honors sslmode query parameter', () {
      expect(
        postgresSslModeFromUrl(
          'postgres://waddle:waddle@db.example.com:5432/waddle?sslmode=disable',
        ),
        pg.SslMode.disable,
      );
      expect(
        postgresSslModeFromUrl(
          'postgres://waddle:waddle@localhost:5432/waddle?sslmode=require',
        ),
        pg.SslMode.require,
      );
      expect(
        postgresSslModeFromUrl(
          'postgres://waddle:waddle@localhost:5432/waddle?sslmode=verify-full',
        ),
        pg.SslMode.verifyFull,
      );
    });

    test('rejects unknown sslmode values', () {
      expect(
        () => postgresSslModeFromUrl(
          'postgres://waddle:waddle@localhost:5432/waddle?sslmode=prefer',
        ),
        throwsArgumentError,
      );
    });
  });
}
