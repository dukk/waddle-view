import 'dart:convert';

import 'package:http/http.dart' as http;

import 'microsoft_graph_base_url.dart';

/// Signed-in Microsoft Graph user profile from `GET .../me`.
class MicrosoftGraphUserProfile {
  const MicrosoftGraphUserProfile({
    required this.id,
    required this.displayName,
    this.mail,
    this.userPrincipalName,
  });

  final String id;
  final String displayName;
  final String? mail;
  final String? userPrincipalName;

  Map<String, dynamic> toJson() => {
        'id': id,
        'display_name': displayName,
        if (mail != null && mail!.isNotEmpty) 'mail': mail,
        if (userPrincipalName != null && userPrincipalName!.isNotEmpty)
          'user_principal_name': userPrincipalName,
      };
}

/// Fetches the signed-in user via Microsoft Graph `GET {graphBase}/{userPath}`.
Future<MicrosoftGraphUserProfile> fetchMicrosoftGraphUserProfile({
  required http.Client httpClient,
  required String graphBaseUrl,
  required String accessToken,
  String userPath = 'me',
}) async {
  final graphBase = normalizeMicrosoftGraphBaseUrl(graphBaseUrl);
  final segment = _userPathSegment(userPath);
  final res = await httpClient.get(
    Uri.parse('$graphBase/$segment'),
    headers: {'Authorization': 'Bearer $accessToken'},
  );
  if (res.statusCode != 200) {
    throw MicrosoftGraphProfileException(
      statusCode: res.statusCode,
      body: res.body,
    );
  }
  final m = jsonDecode(res.body) as Map<String, dynamic>;
  final id = m['id'];
  if (id is! String || id.isEmpty) {
    throw MicrosoftGraphProfileException(
      statusCode: res.statusCode,
      body: 'missing id',
    );
  }
  final displayName = m['displayName'];
  final mail = m['mail'];
  final upn = m['userPrincipalName'];
  return MicrosoftGraphUserProfile(
    id: id,
    displayName: displayName is String && displayName.isNotEmpty
        ? displayName
        : (upn is String && upn.isNotEmpty ? upn : id),
    mail: mail is String && mail.isNotEmpty ? mail : null,
    userPrincipalName: upn is String && upn.isNotEmpty ? upn : null,
  );
}

String _userPathSegment(String mailbox) {
  final m = mailbox.trim();
  if (m.toLowerCase() == 'me') {
    return 'me';
  }
  return 'users/${Uri.encodeComponent(m)}';
}

/// Graph profile request failed.
class MicrosoftGraphProfileException implements Exception {
  MicrosoftGraphProfileException({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final String body;

  @override
  String toString() =>
      'MicrosoftGraphProfileException(status=$statusCode, body=$body)';
}
