import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import '../aes_gcm_secret_cipher.dart';
import 'dek_protector.dart';

/// Windows DPAPI (`CryptProtectData` / `CryptUnprotectData`) for the DEK.
class WindowsDekProtector implements DekProtector {
  WindowsDekProtector({int cryptProtectFlags = CRYPTPROTECT_LOCAL_MACHINE})
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
    final inBlob = calloc<DATA_BLOB>();
    final outBlob = calloc<DATA_BLOB>();
    try {
      inBlob.ref.pbData = calloc<Uint8>(plain.length).cast();
      inBlob.ref.cbData = plain.length;
      final pb = inBlob.ref.pbData.cast<Uint8>();
      for (var i = 0; i < plain.length; i++) {
        pb[i] = plain[i];
      }
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
        throw WindowsException.fromLastError();
      }
      final len = outBlob.ref.cbData;
      final data = outBlob.ref.pbData.cast<Uint8>();
      return List<int>.generate(len, (i) => data[i]);
    } finally {
      if (inBlob.ref.pbData.address != 0) {
        calloc.free(inBlob.ref.pbData);
      }
      if (outBlob.ref.pbData.address != 0) {
        LocalFree(outBlob.ref.pbData);
      }
      calloc.free(inBlob);
      calloc.free(outBlob);
    }
  }

  List<int> _unprotect(Uint8List wrapped) {
    final inBlob = calloc<DATA_BLOB>();
    final outBlob = calloc<DATA_BLOB>();
    try {
      inBlob.ref.pbData = calloc<Uint8>(wrapped.length).cast();
      inBlob.ref.cbData = wrapped.length;
      final pb = inBlob.ref.pbData.cast<Uint8>();
      for (var i = 0; i < wrapped.length; i++) {
        pb[i] = wrapped[i];
      }
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
        throw WindowsException.fromLastError();
      }
      final len = outBlob.ref.cbData;
      final data = outBlob.ref.pbData.cast<Uint8>();
      return List<int>.generate(len, (i) => data[i]);
    } finally {
      if (inBlob.ref.pbData.address != 0) {
        calloc.free(inBlob.ref.pbData);
      }
      if (outBlob.ref.pbData.address != 0) {
        LocalFree(outBlob.ref.pbData);
      }
      calloc.free(inBlob);
      calloc.free(outBlob);
    }
  }
}
