import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import '../aes_gcm_secret_cipher.dart';
import 'dek_protector.dart';

/// `CryptProtectData` / `CryptUnprotectData` flag: any user on this machine.
const int kCryptProtectLocalMachine = 0x04;

/// Windows DPAPI (`CryptProtectData` / `CryptUnprotectData`) for the DEK.
class WindowsDekProtector implements DekProtector {
  WindowsDekProtector({int cryptProtectFlags = kCryptProtectLocalMachine})
      : _flags = cryptProtectFlags;

  final int _flags;

  @override
  Future<List<int>> wrap(List<int> plainDek) async {
    if (plainDek.length != AesGcmSecretCipher.dekLength) {
      throw ArgumentError('plainDek must be ${AesGcmSecretCipher.dekLength} bytes');
    }
    return _protect(Uint8List.fromList(plainDek));
  }

  @override
  Future<List<int>> unwrap(List<int> wrappedDek) async {
    return _unprotect(Uint8List.fromList(wrappedDek));
  }

  List<int> _protect(Uint8List plain) {
    final inBlob = _blobFromBytes(plain);
    final outBlob = calloc<CRYPT_INTEGER_BLOB>();
    try {
      final ok = CryptProtectData(
        inBlob,
        nullptr,
        nullptr,
        nullptr,
        nullptr,
        _flags,
        outBlob,
      );
      if (ok == 0) {
        throw WindowsException(GetLastError());
      }
      return _bytesFromBlob(outBlob);
    } finally {
      _freeBlob(inBlob);
      _freeBlob(outBlob, releaseWithLocalFree: true);
    }
  }

  List<int> _unprotect(Uint8List wrapped) {
    final inBlob = _blobFromBytes(wrapped);
    final outBlob = calloc<CRYPT_INTEGER_BLOB>();
    try {
      final ok = CryptUnprotectData(
        inBlob,
        nullptr,
        nullptr,
        nullptr,
        nullptr,
        _flags,
        outBlob,
      );
      if (ok == 0) {
        throw WindowsException(GetLastError());
      }
      return _bytesFromBlob(outBlob);
    } finally {
      _freeBlob(inBlob);
      _freeBlob(outBlob, releaseWithLocalFree: true);
    }
  }

  Pointer<CRYPT_INTEGER_BLOB> _blobFromBytes(Uint8List data) {
    final blob = calloc<CRYPT_INTEGER_BLOB>();
    final bytes = calloc<Uint8>(data.length);
    bytes.asTypedList(data.length).setAll(0, data);
    blob.ref
      ..cbData = data.length
      ..pbData = bytes;
    return blob;
  }

  List<int> _bytesFromBlob(Pointer<CRYPT_INTEGER_BLOB> blob) {
    final len = blob.ref.cbData;
    if (len == 0) {
      return const [];
    }
    return blob.ref.pbData.asTypedList(len).toList(growable: false);
  }

  void _freeBlob(
    Pointer<CRYPT_INTEGER_BLOB> blob, {
    bool releaseWithLocalFree = false,
  }) {
    final data = blob.ref.pbData;
    if (data.address != 0) {
      if (releaseWithLocalFree) {
        LocalFree(data);
      } else {
        calloc.free(data);
      }
    }
    calloc.free(blob);
  }
}
