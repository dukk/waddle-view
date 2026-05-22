import 'dart:async';
import 'dart:io';

import 'package:waddle_shared/auth/adoption_repository.dart';
import 'package:waddle_shared/config/display_live_preview.dart';

import '../preview/live_preview_capture.dart' show LivePreviewCaptureException;
import '../preview/live_preview_hub.dart';
import '../preview/live_preview_protocol.dart';
import 'display_live_preview_session.dart';

const kDisplayLivePreviewWsPath = '/v1/display/live-preview/ws';

/// WebSocket upgrade for in-app live preview (JPEG frames, view-only).
class DisplayLivePreviewWebSocketGateway {
  DisplayLivePreviewWebSocketGateway({
    required this.adoption,
    this.sessionStore,
    this.hub,
  });

  final AdoptionRepository adoption;
  final DisplayLivePreviewSessionStore? sessionStore;
  final LivePreviewHub? hub;

  bool handlesPath(String path) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return normalized == kDisplayLivePreviewWsPath;
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

    final store = sessionStore ?? displayLivePreviewSessionStore;
    final config = store.consume(ticket);
    if (config == null) {
      await _rejectUpgrade(request, HttpStatus.forbidden, 'invalid_ticket');
      return;
    }

    try {
      final clientWs = await WebSocketTransformer.upgrade(request);
      await _streamPreview(clientWs, config);
    } catch (_) {
      // upgrade or stream failed
    }
  }

  Future<void> _streamPreview(
    WebSocket clientWs,
    DisplayLivePreviewConfig config,
  ) async {
    final previewHub = hub ?? livePreviewHub();
    StreamSubscription<dynamic>? frameSub;
    try {
      await previewHub.attachViewer(config);
    } on LivePreviewCaptureException catch (e) {
      await clientWs.close(1011, e.code);
      return;
    } catch (_) {
      await clientWs.close(1011, 'capture_failed');
      return;
    }

    var closed = false;
    final clientDone = Completer<void>();

    Future<void> closeAll([int? code, String? reason]) async {
      if (closed) return;
      closed = true;
      await frameSub?.cancel();
      frameSub = null;
      await previewHub.detachViewer();
      if (!clientDone.isCompleted) {
        clientDone.complete();
      }
      try {
        await clientWs.close(code, reason);
      } catch (_) {}
    }

    clientWs.listen(
      (_) {},
      onError: (_) => closeAll(),
      onDone: () => closeAll(),
      cancelOnError: true,
    );

    frameSub = previewHub.frames.listen(
      (frame) {
        if (closed) return;
        try {
          clientWs.add(encodeLivePreviewFrame(frame));
        } catch (_) {
          closeAll();
        }
      },
      onError: (Object e, StackTrace _) {
        final code = e is LivePreviewCaptureException ? e.code : 'capture_error';
        closeAll(1011, code);
      },
      onDone: () => closeAll(),
      cancelOnError: true,
    );

    await clientDone.future;
    await closeAll();
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
