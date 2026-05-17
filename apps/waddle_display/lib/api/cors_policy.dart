import 'dart:async';
import 'dart:io';

import 'package:waddle_shared/auth/cors_origin_repository.dart';
import 'package:waddle_shared/auth/cors_origin_normalize.dart';

/// Resolves hostnames for adoption CORS (cached).
typedef HostResolver = Future<List<InternetAddress>> Function(String host);

/// Default resolver using [InternetAddress.lookup].
Future<List<InternetAddress>> defaultHostResolver(String host) =>
    InternetAddress.lookup(host);

class CorsPolicy {
  CorsPolicy({
    HostResolver? hostResolver,
    Duration lookupCacheTtl = const Duration(minutes: 5),
  }) : _hostResolver = hostResolver ?? defaultHostResolver,
       _lookupCacheTtl = lookupCacheTtl;

  final HostResolver _hostResolver;
  final Duration _lookupCacheTtl;
  final Map<String, _LookupCacheEntry> _lookupCache = {};

  /// LAN-friendly origins for unauthenticated adoption routes.
  Future<bool> isAdoptionOriginAllowed(String? rawOrigin) async {
    final origin = normalizeHttpOrigin(rawOrigin);
    if (origin == null) {
      return false;
    }
    final uri = Uri.parse(origin);
    final host = uri.host.toLowerCase();
    if (host == 'localhost' || host.endsWith('.local')) {
      return true;
    }
    final literal = _tryParseAddress(host);
    if (literal != null) {
      return _isPrivateAddress(literal);
    }
    return _hostResolvesPrivateOnly(host);
  }

  /// Origins stored after adoption or seeded from env.
  Future<bool> isProtectedOriginAllowed(
    String? rawOrigin,
    CorsOriginRepository corsOrigins,
  ) async {
    return corsOrigins.isOriginAllowed(rawOrigin);
  }

  Future<bool> _hostResolvesPrivateOnly(String host) async {
    final now = DateTime.now();
    final cached = _lookupCache[host];
    if (cached != null && now.isBefore(cached.expiresAt)) {
      return cached.privateOnly;
    }
    try {
      final addresses = await _hostResolver(host);
      if (addresses.isEmpty) {
        _lookupCache[host] = _LookupCacheEntry(false, now.add(_lookupCacheTtl));
        return false;
      }
      final privateOnly = addresses.every((a) => _isPrivateAddress(a));
      _lookupCache[host] = _LookupCacheEntry(
        privateOnly,
        now.add(_lookupCacheTtl),
      );
      return privateOnly;
    } catch (_) {
      _lookupCache[host] = _LookupCacheEntry(false, now.add(_lookupCacheTtl));
      return false;
    }
  }

  InternetAddress? _tryParseAddress(String host) {
    try {
      return InternetAddress(host);
    } catch (_) {
      return null;
    }
  }

  bool _isPrivateAddress(InternetAddress address) {
    if (address.isLoopback) {
      return true;
    }
    if (address.type == InternetAddressType.IPv4) {
      final parts = address.address.split('.').map(int.parse).toList();
      if (parts.length != 4) {
        return false;
      }
      final a = parts[0];
      final b = parts[1];
      if (a == 10) {
        return true;
      }
      if (a == 172 && b >= 16 && b <= 31) {
        return true;
      }
      if (a == 192 && b == 168) {
        return true;
      }
      if (a == 169 && b == 254) {
        return true;
      }
      return false;
    }
    if (address.type == InternetAddressType.IPv6) {
      final lower = address.address.toLowerCase();
      if (lower == '::1') {
        return true;
      }
      if (lower.startsWith('fc') || lower.startsWith('fd')) {
        return true;
      }
      if (lower.startsWith('fe80:')) {
        return true;
      }
    }
    return false;
  }
}

class _LookupCacheEntry {
  _LookupCacheEntry(this.privateOnly, this.expiresAt);

  final bool privateOnly;
  final DateTime expiresAt;
}

bool isAdoptionPath(String path) {
  final p = path.startsWith('/') ? path : '/$path';
  return p.startsWith('/v1/adoption');
}
