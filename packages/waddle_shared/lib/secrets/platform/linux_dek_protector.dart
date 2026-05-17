import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../aes_gcm_secret_cipher.dart';
import 'dek_protector.dart';

const _kDekWrapSalt = 'waddle-dek-wrap-v1';
const _kMachineIdPaths = [
  '/etc/machine-id',
  '/var/lib/dbus/machine-id',
];

/// Binds the DEK to this host via `/etc/machine-id` and AES-GCM.
class LinuxDekProtector implements DekProtector {
  LinuxDekProtector({Future<String> Function()? readMachineId})
      : _readMachineId = readMachineId ?? _readMachineIdFromFs;

  final Future<String> Function() _readMachineId;

  static Future<String> _readMachineIdFromFs() async {
    for (final path in _kMachineIdPaths) {
      final file = File(path);
      if (await file.exists()) {
        final id = (await file.readAsString()).trim();
        if (id.isNotEmpty) {
          return id;
        }
      }
    }
    throw StateError(
      'Linux machine-id not found (${_kMachineIdPaths.join(' or ')})',
    );
  }

  Future<SecretKey> _hostKek() async {
    final machineId = await _readMachineId();
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: AesGcmSecretCipher.dekLength);
    final keyBytes = await hkdf.deriveKey(
      secretKey: SecretKey(utf8.encode(machineId)),
      info: utf8.encode(_kDekWrapSalt),
    );
    return keyBytes;
  }

  @override
  Future<List<int>> wrap(List<int> plainDek) async {
    if (plainDek.length != AesGcmSecretCipher.dekLength) {
      throw ArgumentError('plainDek must be ${AesGcmSecretCipher.dekLength} bytes');
    }
    final kek = await _hostKek();
    final wire = await AesGcmSecretCipher.encrypt(
      kek,
      Uint8List.fromList(plainDek),
    );
    return wire;
  }

  @override
  Future<List<int>> unwrap(List<int> wrappedDek) async {
    final kek = await _hostKek();
    final plain = await AesGcmSecretCipher.decrypt(
      kek,
      Uint8List.fromList(wrappedDek),
    );
    return plain;
  }
}
