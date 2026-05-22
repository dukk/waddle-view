import 'dart:math';

import 'package:waddle_shared/config/display_remote_view.dart';

/// In-memory Proxmox-style tickets for `/v1/display/remote-view/ws`.
class DisplayRemoteViewSessionStore {
  DisplayRemoteViewSessionStore({Random? random}) : _random = random ?? Random.secure();

  final Random _random;
  final Map<String, _RemoteViewTicket> _tickets = {};

  static const Duration defaultTtl = Duration(minutes: 5);

  /// Creates a ticket for [config]. Returns ticket id and expiry epoch ms.
  ({String ticket, int expiresAtMs}) create(
    DisplayRemoteViewConfig config, {
    Duration ttl = defaultTtl,
  }) {
    _purgeExpired();
    final ticket = _newTicket();
    final expiresAt = DateTime.now().toUtc().add(ttl);
    _tickets[ticket] = _RemoteViewTicket(
      config: config,
      expiresAt: expiresAt,
    );
    return (ticket: ticket, expiresAtMs: expiresAt.millisecondsSinceEpoch);
  }

  /// Consumes [ticket] for a single WebSocket upgrade (single-use).
  DisplayRemoteViewConfig? consume(String ticket) {
    _purgeExpired();
    final entry = _tickets.remove(ticket.trim());
    if (entry == null) return null;
    if (entry.expiresAt.isBefore(DateTime.now().toUtc())) return null;
    return entry.config;
  }

  void _purgeExpired() {
    final now = DateTime.now().toUtc();
    _tickets.removeWhere((_, v) => v.expiresAt.isBefore(now));
  }

  String _newTicket() {
    final bytes = List<int>.generate(24, (_) => _random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}

class _RemoteViewTicket {
  _RemoteViewTicket({required this.config, required this.expiresAt});

  final DisplayRemoteViewConfig config;
  final DateTime expiresAt;
}

/// Process-wide session store for remote-view WebSocket tickets.
final displayRemoteViewSessionStore = DisplayRemoteViewSessionStore();
