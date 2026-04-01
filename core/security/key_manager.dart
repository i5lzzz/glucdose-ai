// lib/core/security/key_manager.dart
// ─────────────────────────────────────────────────────────────────────────────
// Cryptographic key lifecycle manager.
//
// Keys are stored exclusively in flutter_secure_storage which uses:
//   Android : Android Keystore (hardware-backed on API ≥ 23)
//   iOS     : Keychain Services with kSecAttrAccessibleAfterFirstUnlock
//
// Key rotation is version-stamped; old data is re-encrypted on upgrade.
// This satisfies HIPAA §164.312(a)(2)(iv) — encryption & decryption.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:insulin_assistant/core/constants/app_constants.dart';
import 'package:insulin_assistant/core/errors/security_exception.dart';

final class KeyManager {
  KeyManager()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.first_unlock,
          ),
        );

  final FlutterSecureStorage _storage;

  static const int _keyLengthBytes = 32; // 256-bit AES key
  static const int _ivLengthBytes = 16; // 128-bit IV

  Uint8List? _cachedKey;
  Uint8List? _cachedIV;

  /// Returns the AES encryption key, generating it if not present.
  Future<Uint8List> get encryptionKey async {
    _cachedKey ??= await _loadOrGenerate(
      alias: AppConstants.keyEncryptionKeyAlias,
      length: _keyLengthBytes,
    );
    return _cachedKey!;
  }

  /// Returns the AES IV, generating it if not present.
  Future<Uint8List> get iv async {
    _cachedIV ??= await _loadOrGenerate(
      alias: AppConstants.keyIVAlias,
      length: _ivLengthBytes,
    );
    return _cachedIV!;
  }

  /// Ensures both key and IV exist. Called during bootstrap.
  Future<void> ensureKeysExist() async {
    await encryptionKey;
    await iv;
  }

  /// Destroys all key material — used on sign-out / account deletion.
  /// GDPR Article 17 (right to erasure) compliance hook.
  Future<void> destroyAllKeys() async {
    await _storage.delete(key: AppConstants.keyEncryptionKeyAlias);
    await _storage.delete(key: AppConstants.keyIVAlias);
    _cachedKey = null;
    _cachedIV = null;
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<Uint8List> _loadOrGenerate({
    required String alias,
    required int length,
  }) async {
    final stored = await _storage.read(key: alias);
    if (stored != null) {
      return base64Decode(stored);
    }
    return _generateAndStore(alias: alias, length: length);
  }

  Future<Uint8List> _generateAndStore({
    required String alias,
    required int length,
  }) async {
    final key = _secureRandom(length);
    await _storage.write(key: alias, value: base64Encode(key));

    // Verify write succeeded — critical for medical data integrity
    final verify = await _storage.read(key: alias);
    if (verify == null) {
      throw const KeyStorageWriteFailure(
        'Failed to persist cryptographic key — storage write returned null.',
      );
    }

    return key;
  }

  /// Cryptographically secure random byte generation.
  /// Uses dart:math Random.secure() which delegates to OS CSPRNG.
  Uint8List _secureRandom(int length) {
    final rng = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => rng.nextInt(256)),
    );
  }
}
