import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:waddle_shared/integration_accounts/oauth_client_id_metadata.dart';
import 'package:waddle_shared/integration_accounts/oauth_provider_catalog.dart';

void main() {
  group('lookupOAuthClientIdMetadata', () {
    test('parses Microsoft login page config', () async {
      final html = r'''
        <html><body><script>
        $Config={"strAppDisplayName":"Waddle Display","sCompanyDisplayName":"Contoso Ltd"};
        </script></body></html>
      ''';
      final client = MockClient((request) async {
        expect(
          request.url.host,
          'login.microsoftonline.com',
        );
        return http.Response(html, 200);
      });
      final meta = await lookupOAuthClientIdMetadata(
        providerId: kOAuthProviderIdMicrosoftGraph,
        clientId: '00000003-0000-0000-c000-000000000000',
        httpClient: client,
      );
      expect(meta.lookupStatus, 'ok');
      expect(meta.applicationName, 'Waddle Display');
      expect(meta.owner, 'Contoso Ltd');
    });

    test('parses Google brand attribute when present', () async {
      final html =
          '<motion.div data-client-auth-config-brand="My Google App"></motion.div>';
      final client = MockClient((request) async {
        expect(request.url.host, 'accounts.google.com');
        return http.Response(html, 200);
      });
      final meta = await lookupOAuthClientIdMetadata(
        providerId: kOAuthProviderIdGoogle,
        clientId: '123.apps.googleusercontent.com',
        httpClient: client,
      );
      expect(meta.lookupStatus, 'ok');
      expect(meta.applicationName, 'My Google App');
    });

    test('falls back to Google project number when brand missing', () async {
      final client = MockClient((request) async => http.Response('<html></html>', 200));
      final meta = await lookupOAuthClientIdMetadata(
        providerId: kOAuthProviderIdGoogle,
        clientId: '987654321.apps.googleusercontent.com',
        httpClient: client,
      );
      expect(meta.lookupStatus, 'ok');
      expect(meta.applicationName, 'Google Cloud project 987654321');
    });
  });
}
