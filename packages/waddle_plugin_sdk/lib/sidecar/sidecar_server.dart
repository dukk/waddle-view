import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../contracts/collect_contract.dart';
import '../contracts/overlay_contract.dart';
import '../contracts/screen_contract.dart';
import '../contracts/ticker_contract.dart';
import '../manifest/plugin_manifest.dart';

class PluginSidecarHandlers {
  const PluginSidecarHandlers({
    this.onCollect,
    this.tickerItems,
    this.screenState,
    this.overlayState,
    this.health,
  });

  final CollectResponse Function()? onCollect;
  final TickerItemsResponse Function()? tickerItems;
  final PluginTemplateScreenState Function()? screenState;
  final PluginTemplateOverlayState Function()? overlayState;
  final bool Function()? health;
}

Future<HttpServer> runPluginSidecar({
  required PluginManifest manifest,
  required PluginSidecarHandlers handlers,
  InternetAddress? address,
  int? port,
}) async {
  final r = Router();
  r.get('/health', (Request req) {
    final ok = handlers.health?.call() ?? true;
    return Response(ok ? 200 : 503, body: ok ? 'ok' : 'unhealthy');
  });
  r.post('/collect', (Request req) async {
    final res = handlers.onCollect?.call() ?? const CollectResponse();
    return Response.ok(
      jsonEncode(res.toJson()),
      headers: {'content-type': 'application/json'},
    );
  });
  r.get('/ticker/items', (Request req) {
    final res = handlers.tickerItems?.call() ??
        const TickerItemsResponse(items: []);
    return Response.ok(
      jsonEncode(res.toJson()),
      headers: {'content-type': 'application/json'},
    );
  });
  r.get('/screen/state', (Request req) {
    final res = handlers.screenState?.call() ??
        PluginTemplateScreenState(title: manifest.id);
    return Response.ok(
      jsonEncode(res.toJson()),
      headers: {'content-type': 'application/json'},
    );
  });
  r.get('/overlay/state', (Request req) {
    final res = handlers.overlayState?.call() ??
        const PluginTemplateOverlayState();
    return Response.ok(
      jsonEncode(res.toJson()),
      headers: {'content-type': 'application/json'},
    );
  });
  final bindPort = port ?? manifest.sidecar?.port ?? 9876;
  return shelf_io.serve(
    r.call,
    address ?? InternetAddress.loopbackIPv4,
    bindPort,
  );
}
