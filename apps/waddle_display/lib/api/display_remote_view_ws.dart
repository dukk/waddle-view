import 'dart:async';
import 'dart:io';

import 'package:waddle_shared/auth/adoption_repository.dart';
import 'package:waddle_shared/config/display_remote_view.dart';

import 'display_remote_view_session.dart';

const kDisplayRemoteViewWsPath = '/v1/display/remote-view/ws';

/// Handles WebSocket upgrades for remote-view relay (Proxmox-style ticket + API key).
class DisplayRemoteViewWebSocketGateway {
  DisplayRemoteViewWebSocketGateway({
    required this.adoption,
    this.sessionStore,
  });

  final AdoptionRepository adoption;
  final DisplayRemoteViewSessionStore? sessionStore;

  bool handlesPath(String path) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return normalized == kDisplayRemoteViewWsPath;
  }

  Future<void> handle(HttpRequest request) async {
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..write('{"error":"websocket_upgrade_required"}')
        ..close();
      return;
    }

    final ticket = request.uri.queryParameters['ticket']?.trim() ?? '';
    if (ticket.isEmpty) {
      await _rejectUpgrade(request, HttpStatus.badRequest, 'ticket_required');
      return;
    }

    final token = _bearerFromHeaders(request.headers);
    if (token == null || token.isEmpty) {
      await _rejectUpgrade(request, HttpStatus.unauthorized, 'unauthorized');
      return;
    }
    final client = await adoption.clientForApiKey(token);
    if (client == null) {
      await _rejectUpgrade(request, HttpStatus.unauthorized, 'unauthorized');
      return;
    }

    final store = sessionStore ?? displayRemoteViewSessionStore;
    final config = store.consume(ticket);
    if (config == null) {
      await _rejectUpgrade(request, HttpStatus.forbidden, 'invalid_ticket');
      return;
    }

    try {
      final clientWs = await WebSocketTransformer.upgrade(request);
      await _relayToUpstream(clientWs, config.upstreamWebsocketUri);
    } catch (_) {
      // upgrade or relay failed; connection may already be closed
    }
  }

  Future<void> _rejectUpgrade(
    HttpRequest request,
    int status,
    String error,
  ) async {
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write('{"error":"$error"}')
      ..close();
  }

  String? _bearerFromHeaders(HttpHeaders headers) {
    final values = headers['authorization'];
    if (values == null || values.isEmpty) return null;
    final bearer = values.first;
    if (!bearer.toLowerCase().startsWith('bearer ')) return null;
    return bearer.substring(7).trim();
  }
}

Future<void> _relayToUpstream(WebSocket client, Uri upstream) async {
  WebSocket? upstreamWs;
  try {
    upstreamWs = await WebSocket.connect(upstream.toString());
  } catch (_) {
    await client.close(1011, 'upstream_unreachable');
    return;
  }

  final clientSub = client.listen(
    (data) {
      try {
        upstreamWs?.add(data);
      } catch (_) {}
    },
    onError: (_) => upstreamWs?.close(),
    onDone: () => upstreamWs?.close(),
    cancelOnError: true,
  );

  final upstreamSub = upstreamWs.listen(
    (data) {
      try {
        client.add(data);
      } catch (_) {}
    },
    onError: (_) => client.close(),
    onDone: () => client.close(),
    cancelOnError: true,
  );

  await Future.any<void>([
    clientSub.asFuture<void>(),
    upstreamSub.asFuture<void>(),
  ]);
  await clientSub.cancel();
  await upstreamSub.cancel();
  try {
    await upstreamWs.close();
  } catch (_) {}
  try {
    await client.close();
  } catch (_) {}
}
