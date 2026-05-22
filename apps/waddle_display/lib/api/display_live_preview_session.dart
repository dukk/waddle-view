import 'dart:math';

import 'package:waddle_shared/config/display_live_preview.dart';

/// In-memory tickets for `/v1/display/live-preview/ws`.
class DisplayLivePreviewSessionStore {
  DisplayLivePreviewSessionStore({Random? random})
      : _random = random ?? Random.secure();

  final Random _random;
  final Map<String, _LivePreviewTicket> _tickets = {};

  static const Duration defaultTtl = Duration(minutes: 5);

  ({String ticket, int expiresAtMs}) create(
    DisplayLivePreviewConfig config, {
    Duration ttl = defaultTtl,
  }) {
    _purgeExpired();
    final ticket = _newTicket();
    final expiresAt = DateTime.now().toUtc().add(ttl);
    _tickets[ticket] = _LivePreviewTicket(
      config: config,
      expiresAt: expiresAt,
    );
    return (ticket: ticket, expiresAtMs: expiresAt.millisecondsSinceEpoch);
  }

  DisplayLivePreviewConfig? consume(String ticket) {
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

class _LivePreviewTicket {
  _LivePreviewTicket({required this.config, required this.expiresAt});

  final DisplayLivePreviewConfig config;
  final DateTime expiresAt;
}

final displayLivePreviewSessionStore = DisplayLivePreviewSessionStore();
