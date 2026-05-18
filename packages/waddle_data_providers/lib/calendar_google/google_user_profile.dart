import 'dart:convert';

import 'package:http/http.dart' as http;

/// Signed-in Google account from OpenID userinfo.
class GoogleUserProfile {
  const GoogleUserProfile({
    required this.sub,
    required this.name,
    this.email,
    this.picture,
  });

  final String sub;
  final String name;
  final String? email;
  final String? picture;

  Map<String, dynamic> toJson() => {
        'id': sub,
        'display_name': name,
        if (email != null && email!.isNotEmpty) 'email': email,
        if (picture != null && picture!.isNotEmpty) 'picture': picture,
      };
}

/// Fetches the signed-in user via `GET https://www.googleapis.com/oauth2/v3/userinfo`.
Future<GoogleUserProfile> fetchGoogleUserProfile({
  required http.Client httpClient,
  required String accessToken,
}) async {
  final res = await httpClient.get(
    Uri.parse('https://www.googleapis.com/oauth2/v3/userinfo'),
    headers: {'Authorization': 'Bearer $accessToken'},
  );
  if (res.statusCode != 200) {
    throw GoogleUserProfileException(
      statusCode: res.statusCode,
      body: res.body,
    );
  }
  final m = jsonDecode(res.body) as Map<String, dynamic>;
  final sub = m['sub'];
  if (sub is! String || sub.isEmpty) {
    throw GoogleUserProfileException(
      statusCode: res.statusCode,
      body: 'missing sub',
    );
  }
  final name = m['name'];
  final email = m['email'];
  final picture = m['picture'];
  return GoogleUserProfile(
    sub: sub,
    name: name is String && name.isNotEmpty
        ? name
        : (email is String && email.isNotEmpty ? email : sub),
    email: email is String && email.isNotEmpty ? email : null,
    picture: picture is String && picture.isNotEmpty ? picture : null,
  );
}

/// Google userinfo request failed.
class GoogleUserProfileException implements Exception {
  GoogleUserProfileException({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final String body;

  @override
  String toString() => 'GoogleUserProfileException(status=$statusCode, body=$body)';
}
